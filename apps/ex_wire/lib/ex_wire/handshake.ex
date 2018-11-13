defmodule ExWire.Handshake do
  @moduledoc """
  Implements the RLPx ECIES handshake protocol.

  This handshake is the first thing that happens after establishing a connection.
  Afterwards, we will do a HELLO and protocol handshake.

  Note: this protocol is not extremely well defined, but you can read up on it here:
  1. https://github.com/ethereum/devp2p/blob/master/rlpx.md
  2. https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md
  3. https://github.com/ethereum/go-ethereum/wiki/RLPx-Encryption
  4. https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol
  5. https://github.com/ethereum/wiki/wiki/Ethereum-Wire-Protocol
  """

  require Logger

  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.{Key, Math}
  alias ExWire.Framing.Secrets
  alias ExWire.Handshake
  alias ExWire.Handshake.EIP8
  alias ExWire.Handshake.Struct.{AckRespV4, AuthMsgV4}

  defstruct [
    :initiator,
    :remote_pub,
    :init_nonce,
    :resp_nonce,
    :random_key_pair,
    :remote_random_pub,
    :auth_msg,
    :ack_resp,
    :encoded_auth_msg,
    :encoded_ack_resp
  ]

  @type token :: binary()
  @type nonce :: <<_::256>>
  @type t :: %__MODULE__{
          initiator: boolean(),
          remote_pub: Key.public_key() | nil,
          init_nonce: nonce() | nil,
          resp_nonce: nonce() | nil,
          random_key_pair: Key.key_pair(),
          remote_random_pub: Key.public_key() | nil,
          auth_msg: AuthMsgV4.t() | nil,
          ack_resp: AckRespV4.t() | nil,
          encoded_auth_msg: binary() | nil,
          encoded_ack_resp: binary() | nil
        }

  @nonce_len 32

  @doc """
  Generates a new `%ExWire.Handshake{}` struct, setting the owner as the
  initiator of the handshake. It fills the remote's public key with the key
  provided, and it automatically populates it with a new random ephemeral key
  pair and the initiator's nonce.
  """
  @spec new(Key.public_key()) :: t()
  def new(remote_public_key) do
    {ephemeral_key_pair, nonce} = new_random_credentials()

    %__MODULE__{
      initiator: true,
      remote_pub: remote_public_key,
      random_key_pair: ephemeral_key_pair,
      init_nonce: nonce
    }
  end

  @doc """
  Generates a new `%ExWire.Handshake{}` struct when responding, setting the
  owner as the recipient of the handshake. It automatically populates the
  handshake with a new random ephemeral key pair and the response nonce.
  """
  @spec new_response :: t()
  def new_response do
    {ephemeral_key_pair, nonce} = new_random_credentials()

    %__MODULE__{
      initiator: false,
      random_key_pair: ephemeral_key_pair,
      resp_nonce: nonce
    }
  end

  @doc """
  Builds an `AuthMsgV4` (see build_auth_msg/3), serializes it, and encodes it.
  This message is ready to be sent to a peer to initiate the encrypted handshake.
  """
  @spec generate_auth(t()) :: t()
  def generate_auth(handshake = %__MODULE__{remote_pub: remote_pub})
      when not is_nil(remote_pub) do
    auth_msg = build_auth_msg(handshake, ExWire.Config.public_key(), ExWire.Config.private_key())
    encoded_auth_msg = encode_auth(auth_msg, remote_pub, handshake.random_key_pair)

    %{
      handshake
      | auth_msg: auth_msg,
        encoded_auth_msg: encoded_auth_msg
    }
  end

  @doc """
  Builds an `AuthMsgV4` which can be serialized and sent over the wire.
  """
  @spec build_auth_msg(
          t(),
          Key.public_key(),
          Key.private_key()
        ) :: AuthMsgV4.t()
  def build_auth_msg(
        handshake,
        initiator_static_public_key,
        initiator_static_private_key
      ) do
    my_ephemeral_private_key = elem(handshake.random_key_pair, 1)

    {signature, _, _, recovery_id} =
      initiator_static_private_key
      |> ECDH.generate_shared_secret(handshake.remote_pub)
      |> Math.xor(handshake.init_nonce)
      |> ExthCrypto.Signature.sign_digest(my_ephemeral_private_key)

    compact_signature = ExthCrypto.Signature.compact_format(signature, recovery_id)

    %AuthMsgV4{
      signature: compact_signature,
      initiator_public_key: initiator_static_public_key,
      initiator_nonce: handshake.init_nonce,
      initiator_version: ExWire.Config.protocol_version()
    }
  end

  @doc """
  Builds a response for an incoming authentication message.
  It also generates a new ephemeral key pair and nonce.
  """
  @spec build_ack_resp(t()) :: AckRespV4.t()
  def build_ack_resp(handshake = %Handshake{}) do
    ephemeral_public_key = elem(handshake.random_key_pair, 0)

    %AckRespV4{
      recipient_nonce: handshake.resp_nonce,
      recipient_ephemeral_public_key: ephemeral_public_key,
      recipient_version: ExWire.Config.protocol_version()
    }
  end

  @doc """
  Given an incoming message, let's try to accept it as an ack resp. If that works,
  we'll derive our secrets from it.

  # TODO: Add examples
  """
  @spec handle_ack(t(), binary()) ::
          {:ok, t(), Secrets.t(), binary()}
          | {:invalid, :invalid_ECIES_encoded_message | :invalid_message_tag}
  def handle_ack(handshake = %Handshake{}, ack_data) do
    case read_ack_resp(ack_data, ExWire.Config.private_key()) do
      {:ok, ack_resp, ack_resp_bin, frame_rest} ->
        updated_handshake = add_ack_data(handshake, ack_resp, ack_resp_bin)
        secrets = ExWire.Framing.Secrets.derive_secrets(updated_handshake)

        {:ok, updated_handshake, secrets, frame_rest}

      {:error, reason} ->
        {:invalid, reason}
    end
  end

  @spec add_ack_data(t(), AckRespV4.t(), binary()) :: t()
  defp add_ack_data(handshake, ack_resp = %AckRespV4{}, encoded_ack_data) do
    %Handshake{
      handshake
      | resp_nonce: ack_resp.recipient_nonce,
        remote_random_pub: ack_resp.recipient_ephemeral_public_key,
        ack_resp: ack_resp,
        encoded_ack_resp: encoded_ack_data
    }
  end

  @doc """
  Give an incoming msg, let's try to accept it as an auth msg. If that works,
  we'll prepare an ack response to send back and derive our secrets.

  TODO: Add examples
  """
  @spec handle_auth(t(), binary()) ::
          {:ok, t(), Secrets.t()}
          | {:invalid, :invalid_ECIES_encoded_message | :invalid_message_tag}
  def handle_auth(handshake = %Handshake{}, auth_data) do
    case read_auth_msg(auth_data, ExWire.Config.private_key()) do
      {:ok, auth_msg, <<>>} ->
        resp_handshake =
          handshake
          |> add_auth_data(auth_msg, auth_data)
          |> generate_ack_resp()

        secrets = ExWire.Framing.Secrets.derive_secrets(resp_handshake)

        {:ok, resp_handshake, secrets}

      {:error, reason} ->
        {:invalid, reason}
    end
  end

  @spec add_auth_data(t(), AuthMsgV4.t(), binary()) :: t()
  defp add_auth_data(handshake, auth_msg = %AuthMsgV4{}, encoded_auth_data) do
    %AuthMsgV4{
      initiator_public_key: initiator_public_key,
      initiator_nonce: initiator_nonce,
      initiator_ephemeral_public_key: initiator_ephemeral_public_key
    } = auth_msg

    %{
      handshake
      | remote_pub: initiator_public_key,
        init_nonce: initiator_nonce,
        remote_random_pub: initiator_ephemeral_public_key,
        auth_msg: auth_msg,
        encoded_auth_msg: encoded_auth_data
    }
  end

  @spec generate_ack_resp(t()) :: t()
  defp generate_ack_resp(handshake) do
    ack_resp = build_ack_resp(handshake)
    encoded_ack_resp = encode_ack(ack_resp, handshake.remote_pub, handshake.random_key_pair)

    %{handshake | ack_resp: ack_resp, encoded_ack_resp: encoded_ack_resp}
  end

  @spec encode_auth(AuthMsgV4.t(), Key.public_key(), Key.key_pair()) :: binary()
  defp encode_auth(auth_msg = %AuthMsgV4{}, remote_pub, initiator_ephemeral_key_pair) do
    {:ok, encoded_auth_msg} =
      auth_msg
      |> AuthMsgV4.serialize()
      |> EIP8.wrap_eip_8(remote_pub, initiator_ephemeral_key_pair)

    encoded_auth_msg
  end

  @spec encode_ack(AckRespV4.t(), Key.public_key(), Key.key_pair()) :: binary()
  defp encode_ack(ack_resp = %AckRespV4{}, remote_pub, recipient_ephemeral_key_pair) do
    {:ok, encoded_ack_resp} =
      ack_resp
      |> AckRespV4.serialize()
      |> EIP8.wrap_eip_8(remote_pub, recipient_ephemeral_key_pair)

    encoded_ack_resp
  end

  @doc """
  Reads a given auth message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the listener of the connection.

  Note: this will handle pre or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_auth_msg(<<_::16, _::_*8>>, Key.private_key()) ::
          {:ok, AuthMsgV4.t(), binary()}
          | {:error, :invalid_ECIES_encoded_message | :invalid_message_tag}
  def read_auth_msg(encoded_auth, my_static_private_key) do
    case EIP8.unwrap_eip_8(encoded_auth, my_static_private_key) do
      {:ok, rlp, _bin, frame_rest} ->
        # unwrap eip-8
        auth_msg =
          rlp
          |> AuthMsgV4.deserialize()
          |> AuthMsgV4.set_initiator_ephemeral_public_key(my_static_private_key)

        {:ok, auth_msg, frame_rest}

      {:error, _} ->
        # unwrap plain
        with {:ok, plaintext} <-
               ExthCrypto.ECIES.decrypt(my_static_private_key, encoded_auth, <<>>, <<>>) do
          <<
            signature::binary-size(65),
            _::binary-size(32),
            initiator_public_key::binary-size(64),
            initiator_nonce::binary-size(32),
            0x00::size(8)
          >> = plaintext

          auth_msg =
            [
              signature,
              initiator_public_key,
              initiator_nonce,
              ExWire.Config.protocol_version()
            ]
            |> AuthMsgV4.deserialize()
            |> AuthMsgV4.set_initiator_ephemeral_public_key(my_static_private_key)

          {:ok, auth_msg, <<>>}
        end
    end
  end

  @doc """
  Reads a given ack message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the dialer of the connection.

  Note: this will handle pre- or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_ack_resp(<<_::16, _::_*8>>, Key.private_key()) ::
          {:ok, AckRespV4.t(), binary(), binary()}
          | {:error, :invalid_ECIES_encoded_message | :invalid_message_tag}
  def read_ack_resp(encoded_ack, my_static_private_key) do
    case EIP8.unwrap_eip_8(encoded_ack, my_static_private_key) do
      {:ok, rlp, ack_resp_bin, frame_rest} ->
        # unwrap eip-8
        ack_resp =
          rlp
          |> AckRespV4.deserialize()

        {:ok, ack_resp, ack_resp_bin, frame_rest}

      {:error, _reason} ->
        # TODO: reason?

        # unwrap plain
        with {:ok, plaintext} <-
               ExthCrypto.ECIES.decrypt(my_static_private_key, encoded_ack, <<>>, <<>>) do
          <<
            recipient_ephemeral_public_key::binary-size(64),
            recipient_nonce::binary-size(32),
            0x00::size(8)
          >> = plaintext

          ack_resp =
            [
              recipient_ephemeral_public_key,
              recipient_nonce,
              ExWire.Config.protocol_version()
            ]
            |> AckRespV4.deserialize()

          {:ok, ack_resp, encoded_ack, <<>>}
        end
    end
  end

  @spec new_random_credentials :: {Key.key_pair(), nonce()}
  defp new_random_credentials do
    {new_ephemeral_key_pair(), new_nonce()}
  end

  @spec new_nonce() :: nonce()
  def new_nonce do
    Math.nonce(@nonce_len)
  end

  @spec new_ephemeral_key_pair() :: Key.key_pair()
  def new_ephemeral_key_pair do
    ECDH.new_ecdh_keypair()
  end
end
