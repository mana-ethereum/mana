defmodule ExWire.Handshake do
  @moduledoc """
  Defines the protocols to complete an ECEIS handshake with a remote peer.

  Note: we've foll
  """

  require Logger

  alias ExthCrypto.ECIES.ECDH
  alias ExWire.Handshake.EIP8

  @type token :: binary()

  defmodule Handshake do
    defstruct [
      :initiator,
      :remote_id,
      :remote_pub,        # ecdhe-random
      :init_nonce,        # nonce
      :resp_nonce,        #
      :random_priv_key,   # ecdhe-random
      :remote_random_pub, # ecdhe-random-pubk
    ]

    @type t :: %__MODULE__{
      initiator: boolean(),
      remote_id: ExWire.node_id,
      remote_pub: ExWire.private_key(),
      init_nonce: binary(),
      resp_nonce: binary(),
      random_priv_key: ExWire.private_key,
      remote_random_pub: ExWire.pubic_key,
    }
  end

  defmodule Secrets do
    defstruct [
      :remote_id,
      :aes,
      :mac,
      :egress_mac,
      :ingress_mac,
      :token,
    ]

    @type t :: %__MODULE__{
      remote_id: ExWire.node_id,
      aes: binary(),
      mac: binary(),
      egress_mac: binary(),
      ingress_mac: binary(),
      token: binary(),
    }
  end

  # const V4_AUTH_PACKET_SIZE: usize = 307;
  # const V4_ACK_PACKET_SIZE: usize = 210;
  # const HANDSHAKE_TIMEOUT: u64 = 5000;

  @protocol_version 4

  # RLPx v4 handshake auth (defined in EIP-8).
  defmodule AuthMsgV4 do
    @moduledoc """
    Simple struct to wrap an auth msg.
    """

    defstruct [:signature, :remote_public_key, :remote_nonce, :remote_version, :remote_ephemeral_public_key]

    @type t :: %__MODULE__{
      signature: ExthCrypto.signature,
      remote_public_key: ExthCrypto.Key.public_key,
      remote_nonce: binary(),
      remote_version: integer(),
      remote_ephemeral_public_key: ExthCrypto.Key.public_key,
    }

    @spec serialize(t) :: ExRLP.t
    def serialize(auth_msg) do
      [
        auth_msg.signature,
        auth_msg.remote_public_key,
        auth_msg.remote_nonce,
        auth_msg.remote_version
      ]
    end

    @spec deserialize(ExRLP.t) :: t
    def deserialize(rlp) do
      [
        signature |
        [remote_public_key |
        [remote_nonce |
        [remote_version |
        _tl
      ]]]] = rlp

      %__MODULE__{
        signature: signature,
        remote_public_key: remote_public_key |> ExthCrypto.Key.raw_to_der,
        remote_nonce: remote_nonce,
        remote_version: remote_version |> :binary.decode_unsigned,
      }
    end

    @doc """
    Sets the remote ephemeral public key for a given auth msg, based on our secret
    and the keys passed from remote.

    # TODO: Test
    # TODO: Multiple possible values and no recovery key?
    """
    @spec set_remote_ephemeral_public_key(t, ExthCrypto.Key.public_key) :: t
    def set_remote_ephemeral_public_key(auth_msg, host_secret) do
      shared_secret = ECDH.generate_shared_secret(host_secret, auth_msg.remote_public_key)
      shared_secret_xor_nonce = :crypto.exor(shared_secret, auth_msg.remote_nonce)

      {:ok, remote_ephemeral_public_key} = ExthCrypto.Signature.recover(shared_secret_xor_nonce, auth_msg.signature, 0)

      %{auth_msg | remote_ephemeral_public_key: remote_ephemeral_public_key}
    end
  end

  defmodule AckRespV4 do
    @moduledoc """
    Simple struct to wrap an auth response.
    """

    defstruct [:remote_ephemeral_public_key, :remote_nonce, :remote_version]

    @type t :: %__MODULE__{
      remote_ephemeral_public_key: ExthCrypto.Key.public_key,
      remote_nonce: binary(),
      remote_version: integer(),
    }

    @spec serialize(t) :: ExRLP.t
    def serialize(auth_resp) do
      [
        auth_resp.remote_ephemeral_public_key,
        auth_resp.remote_nonce,
        auth_resp.remote_version,
      ]
    end

    @spec deserialize(ExRLP.t) :: t
    def deserialize(rlp) do
      [
        remote_ephemeral_public_key |
        [remote_nonce |
        [remote_version |
        _tl
      ]]] = rlp

      %__MODULE__{
        remote_ephemeral_public_key: remote_ephemeral_public_key,
        remote_nonce: remote_nonce,
        remote_version: remote_version |> :binary.decode_unsigned,
      }
    end
  end

  @doc """
  Reads a given auth message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the listener of the connection.

  Note: this will handle pre or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_auth_msg(binary(), ExthCrypto.Key.private_key, String.t) :: {:ok, AuthMsgV4.t} | {:error, String.t}
  def read_auth_msg(encoded_auth, my_private_key, remote_addr) do
    case EIP8.unwrap_eip_8(encoded_auth, my_private_key, "1.2.3.4") do
      {:ok, rlp} ->
        # unwrap eip-8
        auth_msg =
          rlp
          |> ExWire.Handshake.AuthMsgV4.deserialize()
          |> ExWire.Handshake.AuthMsgV4.set_remote_ephemeral_public_key(my_private_key)

        {:ok, auth_msg}
      {:error, "Invalid auth size"} ->
        # unwrap plain
        with {:ok, plaintext} <- ExthCrypto.ECIES.decrypt(my_private_key, encoded_auth, <<>>, <<>>) do
          <<
            signature::binary-size(65),
            _::binary-size(32),
            remote_public_key::binary-size(64),
            remote_nonce::binary-size(32),
            _rest::bitstring()
          >> = plaintext

          auth_msg =
            [
              signature,
              remote_public_key,
              remote_nonce,
              :binary.encode_unsigned(@protocol_version)
            ]
            |> ExWire.Handshake.AuthMsgV4.deserialize()
            |> ExWire.Handshake.AuthMsgV4.set_remote_ephemeral_public_key(my_private_key)

          {:ok, auth_msg}
        end
    end
  end

  @doc """
  Reads a given ack message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the dialer of the connection.

  Note: this will handle pre or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_ack_resp(binary(), ExthCrypto.Key.private_key, String.t) :: {:ok, AckRespV4.t} | {:error, String.t}
  def read_ack_resp(encoded_ack, my_private_key, remote_addr) do
    case EIP8.unwrap_eip_8(encoded_ack, my_private_key, "1.2.3.4") do
      {:ok, rlp} ->
        # unwrap eip-8
        ack_resp =
          rlp
          |> ExWire.Handshake.AckRespV4.deserialize()

        {:ok, ack_resp}
      {:error, "Invalid auth size"} ->
        # unwrap plain
        with {:ok, plaintext} <- ExthCrypto.ECIES.decrypt(my_private_key, encoded_ack, <<>>, <<>>) do
          <<
            remote_ephemeral_public_key::binary-size(64),
            remote_nonce::binary-size(32),
            _rest::bitstring()
          >> = plaintext

          ack_resp =
            [
              remote_ephemeral_public_key,
              remote_nonce,
              :binary.encode_unsigned(@protocol_version)
            ]
            |> ExWire.Handshake.AckRespV4.deserialize()

          {:ok, ack_resp}
        end
    end
  end

  @doc """
  Generates an auth header

  ## Examples

      iex> ExWire.Handshake.gen_auth(public_key, remote_addr, my_ephemeral_key_pair, init_vector, padding)
  """
  # def gen_auth(ExthCrypto.Handshake.AuthMsgV4.t, ExthCrypto.Key.public_key, Stringt.t, {ExthCrypto.Key.public_key, ExthCrypto.Key.private_key} | nil, Cipher.init_vector | nil, binary() | nil) :: {:ok, binary()} | {:error, String.t}
  # def gen_auth(msg_auth, her_static_public_key, remote_addr, my_ephemeral_key_pair \\ nil, init_vector \\ nil, padding \\ nil) do
  #   her_static_public_key = ..
  #   remote_addr = ..
  #   MsgAuthV4.serialize(msg_auth)
  #   |> wrap_eip_8(her_static_public_key, remote_addr, my_ephemeral_key_pair, init_vector, padding)
  # end

  @doc """
  Generates an ack header

  ## Examples

      iex> ExWire.Handshake.gen_ack(public_key, remote_addr, my_ephemeral_key_pair, init_vector, padding)
  """
  # def gen_ack(ExthCrypto.Handshake.AuthMsgV4.t, ExthCrypto.Key.public_key, Stringt.t, {ExthCrypto.Key.public_key, ExthCrypto.Key.private_key} | nil, Cipher.init_vector | nil, binary() | nil) :: {:ok, binary()} | {:error, String.t}
  # def gen_ack(msg_auth, her_static_public_key, remote_addr, my_ephemeral_key_pair \\ nil, init_vector \\ nil, padding \\ nil) do
  #   her_static_public_key = ..
  #   remote_addr = ..
  #   MsgAuthV4.serialize(msg_auth)
  #   |> wrap_eip_8(her_static_public_key, remote_addr, my_ephemeral_key_pair, init_vector, padding)
  # end

  @doc """
  From the (updated) docs here: https://github.com/ethereum/devp2p/pull/34/files

  ```
  The initiator generates a random key pair, nonce and constructs `enc-auth-msg-initiator`, which it then sends to the recipient.
 
      version = 0x0000000000000005
      token-flag = 0x00
      initiator-nonce = <24 random bytes>
      initiator-nonce-data = nonce || version
      static-shared-secret = ecdh.agree(initiator-privk, recipient-pubk)
      initiator-sig =
          sign(initiator-ephemeral-privk, static-shared-secret ^ initiator-nonce-data)
      auth-msg-initiator =
          initiator-sig ||
          sha3(initiator-ephemeral-pubk) ||
          initiator-pubk ||
          nonce ||
          version ||
          token-flag
      enc-auth-msg-initiator = ecies.encrypt(recipient-pubk, auth-msg-initiator)
  ```
  """
  # @spec make_auth_msg(ExthCrypto.Key.private_key, token) :: {:ok, AuthMsgV4.t} | {:error, String.t}
  # def make_auth_msg(node_id, token) do
  #   my_ephemeral_private_key = .. #

  #   with {:ok, public_key} <- Crypto.node_id(private_key) do
  #     version = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05>>
  #     token_flag = <<0x00>>

  #     initiator_nonce = ExthCrypto.Math.nonce(24) # TODO: Shalen
  #     initiator_nonce_data = nonce <> version
  #     static_shared_secret = ExthCrypto.ECDH(my_static_private_key, her_static_public_key)
  #     initator_sig = ExthCrypto.Signature.sign(static_shared_secret ^ initiator_nonce_data, my_ephemeral_private_key)
  #     auth_msg_initiator =
  #       initator_sig <>
  #       sha3(my_ephemeral_public_key) <>
  #       my_static_public_key <>
  #       nonce <>
  #       version <>
  #       token_flag

  #     # TODO: Add optional params such as my_ephemeral_key_pair or init_vector?
  #     enc_auth_msg_initiator = ExthCrypto.ECIES.encrypt(her_static_public_key, auth_msg_initiator, <<>>, <<>>)

  #   end
  # end


  @doc """
  After dailing a connection, perform handshake to generate secure connection.

  # TODO: Conn?
  # TODO: Token?

  """
  # @spec initiate_connection(conn, ExthCrypto.Key.private_key, ExthCrypto.Key.public_key, ExWire.node_id, token) :: {:ok, Secrets.t} | {:error, String.t}
  # def initiate_connection(conn, my_static_private_key, her_static_public_key, node_id, token) do
  #   handshake = %Handshake{
  #     initiator: true,
  #     remote_id: node_id,
  #   }
    





  # end

end