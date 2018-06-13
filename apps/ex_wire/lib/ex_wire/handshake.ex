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
  alias ExWire.Handshake.EIP8
  alias ExWire.Handshake.Struct.AuthMsgV4
  alias ExWire.Handshake.Struct.AckRespV4
  alias ExWire.Framing.Secrets

  defstruct [
    :initiator,
    :remote_pub,
    :init_nonce,
    :resp_nonce,
    :random_key_pair,
    :remote_random_pub,
    :encoded_auth_msg
  ]

  @type token :: binary()
  @type nonce :: <<_::256>>
  @type t :: %__MODULE__{
          initiator: boolean(),
          remote_pub: ExthCrypto.Key.public_key(),
          init_nonce: nonce(),
          resp_nonce: nonce(),
          random_key_pair: ExthCrypto.Key.key_pair(),
          remote_random_pub: ExthCrypto.Key.pubic_key(),
          encoded_auth_msg: binary()
        }

  @nonce_len 32

  @doc """
  Builds an AuthMsgV4 (see build_auth_msg/3), serializes it, and encodes it.
  This message is ready to be sent to a peer to initiate the encrypted handshake.
  """
  @spec initiate(Handshake.t()) :: Handshake.t()
  def initiate(handshake) do
    {auth_msg, initiator_ephemeral_key_pair, initiator_nonce} =
      build_auth_msg(
        ExWire.Config.public_key(),
        ExWire.Config.private_key(),
        handshake.remote_pub
      )

    {:ok, encoded_auth_msg} =
      auth_msg
      |> AuthMsgV4.serialize()
      |> EIP8.wrap_eip_8(
        handshake.remote_pub,
        initiator_ephemeral_key_pair
      )

    %{
      handshake
      | initiator: true,
        init_nonce: initiator_nonce,
        random_key_pair: initiator_ephemeral_key_pair,
        encoded_auth_msg: encoded_auth_msg
    }
  end

  @doc """
  Reads a given auth message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the listener of the connection.

  Note: this will handle pre or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_auth_msg(binary(), ExthCrypto.Key.private_key()) ::
          {:ok, AuthMsgV4.t(), binary()} | {:error, String.t()}
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
  @spec read_ack_resp(binary(), ExthCrypto.Key.private_key()) ::
          {:ok, AckRespV4.t(), binary(), binary()} | {:error, String.t()}
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

  @doc """
  Builds an AuthMsgV4 which can be serialized and sent over the wire. This will also build an ephemeral key pair
  to use during the signing process.
  """
  @spec build_auth_msg(
          ExthCrypto.Key.public_key(),
          ExthCrypto.Key.private_key(),
          ExthCrypto.Key.public_key()
        ) :: {AuthMsgV4.t(), ExthCrypto.Key.key_pair(), nonce()}
  def build_auth_msg(
        initiator_static_public_key,
        initiator_static_private_key,
        recipient_static_public_key
      ) do
    # Geneate a random ephemeral keypair
    my_ephemeral_keypair = new_ephemeral_key_pair()

    {_my_ephemeral_public_key, my_ephemeral_private_key} = my_ephemeral_keypair

    # Determine DH shared secret
    shared_secret =
      ECDH.generate_shared_secret(initiator_static_private_key, recipient_static_public_key)

    # Build a nonce unless given
    nonce = new_nonce()

    # XOR shared-secret and nonce
    shared_secret_xor_nonce = ExthCrypto.Math.xor(shared_secret, nonce)

    # Sign xor'd secret
    {signature, _, _, recovery_id} =
      ExthCrypto.Signature.sign_digest(shared_secret_xor_nonce, my_ephemeral_private_key)

    compact_signature = ExthCrypto.Signature.compact_format(signature, recovery_id)

    # Build an auth message to send over the wire
    auth_msg = %AuthMsgV4{
      signature: compact_signature,
      initiator_public_key: initiator_static_public_key,
      initiator_nonce: nonce,
      initiator_version: ExWire.Config.protocol_version()
    }

    # Return auth_msg and my new key pair
    {auth_msg, my_ephemeral_keypair, nonce}
  end

  @doc """
  Builds a response for an incoming authentication message.
  It also generates a new ephemeral key pair and nonce.
  """
  @spec build_ack_resp() :: AckRespV4.t()
  def build_ack_resp() do
    ephemeral_key_pair = new_ephemeral_key_pair()
    {ephemeral_public_key, _private_key} = ephemeral_key_pair
    nonce = new_nonce()

    ack_resp = %AckRespV4{
      recipient_nonce: nonce,
      recipient_ephemeral_public_key: ephemeral_public_key,
      recipient_version: ExWire.Config.protocol_version()
    }

    {ack_resp, ephemeral_key_pair, nonce}
  end

  @doc """
  Given an incoming message, let's try to accept it as an ack resp. If that works,
  we'll derive our secrets from it.

  # TODO: Add examples
  """
  @spec try_handle_ack(binary(), binary(), ExthCrypto.Key.private_key(), nonce()) ::
          {:ok, Secrets.t(), binary()} | {:invalid, String.t()}
  def try_handle_ack(ack_data, auth_data, my_ephemeral_private_key, my_nonce) do
    case ExWire.Handshake.read_ack_resp(ack_data, ExWire.Config.private_key()) do
      {:ok,
       %ExWire.Handshake.Struct.AckRespV4{
         recipient_ephemeral_public_key: recipient_ephemeral_public_key,
         recipient_nonce: recipient_nonce
       }, ack_data_limited, frame_rest} ->
        # We're the initiator, by definition since we got an ack resp.
        secrets =
          ExWire.Framing.Secrets.derive_secrets(
            true,
            my_ephemeral_private_key,
            recipient_ephemeral_public_key,
            recipient_nonce,
            my_nonce,
            auth_data,
            ack_data_limited
          )

        {:ok, secrets, frame_rest}

      {:error, reason} ->
        {:invalid, reason}
    end
  end

  @doc """
  Give an incoming msg, let's try to accept it as an auth msg. If that works,
  we'll prepare an ack response to send back and derive our secrets.

  TODO: Add examples
  """
  @spec handle_auth(binary()) :: {:ok, binary(), Secrets.t()} | {:invalid, String.t()}
  def handle_auth(auth_data) do
    case ExWire.Handshake.read_auth_msg(auth_data, ExWire.Config.private_key()) do
      {:ok,
       %ExWire.Handshake.Struct.AuthMsgV4{
         signature: _signature,
         initiator_public_key: initiator_public_key,
         initiator_nonce: initiator_nonce,
         initiator_version: _initiator_version,
         initiator_ephemeral_public_key: initiator_ephemeral_public_key
       }, <<>>} ->
        # First, we'll build an ack, which we'll respond with to the initiator
        {ack_resp, recipient_ephemeral_key_pair, recipient_nonce} =
          ExWire.Handshake.build_ack_resp()

        {:ok, encoded_ack_resp} =
          ack_resp
          |> ExWire.Handshake.Struct.AckRespV4.serialize()
          |> ExWire.Handshake.EIP8.wrap_eip_8(initiator_public_key, recipient_ephemeral_key_pair)

        {_public_key, recipient_ephemeral_private_key} = recipient_ephemeral_key_pair
        # We have the auth, we can derive secrets already
        secrets =
          ExWire.Framing.Secrets.derive_secrets(
            false,
            recipient_ephemeral_private_key,
            initiator_ephemeral_public_key,
            initiator_nonce,
            recipient_nonce,
            auth_data,
            encoded_ack_resp
          )

        {:ok, encoded_ack_resp, secrets}

      {:error, reason} ->
        {:invalid, reason}
    end
  end

  @spec new_nonce() :: nonce()
  def new_nonce do
    ExthCrypto.Math.nonce(@nonce_len)
  end

  @spec new_ephemeral_key_pair() :: ExthCrypto.Key.key_pair()
  def new_ephemeral_key_pair do
    ECDH.new_ecdh_keypair()
  end
end
