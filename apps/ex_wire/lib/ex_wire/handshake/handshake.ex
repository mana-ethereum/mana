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

  # @handshake_timeout 5000
  @protocol_version 4
  @nonce_len 32

  @doc """
  Reads a given auth message, transported during the key initialization phase
  of the RLPx protocol. This will generally be handled by the listener of the connection.

  Note: this will handle pre or post-EIP 8 messages. We take a different approach to other
        implementations and try EIP-8 first, and if that fails, plain.
  """
  @spec read_auth_msg(binary(), ExthCrypto.Key.private_key, String.t) :: {:ok, AuthMsgV4.t} | {:error, String.t}
  def read_auth_msg(encoded_auth, my_static_private_key, remote_addr) do
    case EIP8.unwrap_eip_8(encoded_auth, my_static_private_key, remote_addr) do
      {:ok, rlp} ->
        # unwrap eip-8
        auth_msg =
          rlp
          |> AuthMsgV4.deserialize()
          |> AuthMsgV4.set_remote_ephemeral_public_key(my_static_private_key)

        {:ok, auth_msg}
      {:error, "Invalid auth size"} ->
        # unwrap plain
        with {:ok, plaintext} <- ExthCrypto.ECIES.decrypt(my_static_private_key, encoded_auth, <<>>, <<>>) do
          <<
            signature::binary-size(65),
            _::binary-size(32),
            remote_public_key::binary-size(64),
            remote_nonce::binary-size(32),
            0x00::size(8)
          >> = plaintext

          auth_msg =
            [
              signature,
              remote_public_key,
              remote_nonce,
              @protocol_version
            ]
            |> AuthMsgV4.deserialize()
            |> AuthMsgV4.set_remote_ephemeral_public_key(my_static_private_key)

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
  def read_ack_resp(encoded_ack, my_static_private_key, remote_addr) do
    case EIP8.unwrap_eip_8(encoded_ack, my_static_private_key, remote_addr) do
      {:ok, rlp} ->
        # unwrap eip-8
        ack_resp =
          rlp
          |> AckRespV4.deserialize()

        {:ok, ack_resp}
      {:error, "Invalid auth size"} ->
        # unwrap plain
        with {:ok, plaintext} <- ExthCrypto.ECIES.decrypt(my_static_private_key, encoded_ack, <<>>, <<>>) do
          <<
            remote_ephemeral_public_key::binary-size(64),
            remote_nonce::binary-size(32),
            0x00::size(8)
          >> = plaintext

          ack_resp =
            [
              remote_ephemeral_public_key,
              remote_nonce,
              @protocol_version
            ]
            |> AckRespV4.deserialize() |> Exth.inspect("ack_resp")

          {:ok, ack_resp}
        end
    end
  end

  @doc """
  Builds an AuthMsgV4 which can be serialized and sent over the wire. This will also build an ephemeral key pair
  to use during the signing process.

  ## Examples

      iex> ExWire.Handshake.build_auth_msg(ExthCrypto.Test.public_key(:key_a), ExthCrypto.Test.private_key(:key_a), ExthCrypto.Test.public_key(:key_b), ExthCrypto.Test.init_vector(1, 32), ExthCrypto.Test.key_pair(:key_c))
      {
        %ExWire.Handshake.Struct.AuthMsgV4{
          remote_ephemeral_public_key: nil,
          remote_nonce: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>,
          remote_public_key: <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215, 159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161, 171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155, 120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>,
          remote_version: 4,
          signature: <<127, 216, 231, 36, 238, 232, 137, 16, 83, 221, 94, 111, 232, 164, 133, 148, 56, 55, 207, 103, 124, 143, 158, 123, 191, 142, 235, 11, 171, 21, 214, 228, 124, 34, 84, 243, 6, 156, 191, 33, 63, 64, 87, 47, 10, 216, 238, 251, 252, 29, 10, 135, 142, 164, 122, 70, 138, 193, 40, 188, 36, 84, 144, 17>>
        },
        {
          <<4, 146, 201, 161, 205, 19, 177, 147, 33, 107, 190, 144, 81, 145, 173, 83,
            20, 105, 150, 114, 196, 249, 143, 167, 152, 63, 225, 96, 184, 86, 203, 38,
            134, 241, 40, 152, 74, 34, 68, 233, 204, 91, 240, 208, 254, 62, 169, 53,
            201, 248, 156, 236, 34, 203, 156, 75, 18, 121, 162, 104, 3, 164, 156, 46, 186>>,
          <<178, 68, 134, 194, 0, 187, 118, 35, 33, 220, 4, 3, 50, 96, 97, 91, 96, 14,
            71, 239, 7, 102, 33, 187, 194, 221, 152, 36, 95, 22, 121, 48>>
        },
        <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>
      }
  """
  @spec build_auth_msg(ExthCrypto.Key.public_key, ExthCrypto.Key.private_key, ExthCrypto.Key.public_key, binary() | nil, ExthCrypto.Key.key_pair | nil) :: {AuthMsgV4.t, ExthCrypto.Key.key_pair, binary()}
  def build_auth_msg(my_static_public_key, my_static_private_key, her_static_public_key, nonce \\ nil, my_ephemeral_keypair \\ nil) do

    # Geneate a random ephemeral keypair
    my_ephemeral_keypair = if my_ephemeral_keypair, do: my_ephemeral_keypair, else: ECDH.new_ecdh_keypair()

    {my_ephemeral_public_key, my_ephemeral_private_key} = my_ephemeral_keypair |> Exth.inspect("my_ephemeral_key_pair")

    # Determine DH shared secret
    shared_secret = ECDH.generate_shared_secret(my_static_private_key, her_static_public_key) |> Exth.inspect("shared_secret")

    # Build a nonce unless given
    nonce = ( if nonce, do: nonce, else: ExthCrypto.Math.nonce(@nonce_len) ) |> Exth.inspect("nonce")

    # XOR shared-secret and nonce
    shared_secret_xor_nonce = ExthCrypto.Math.xor(shared_secret, nonce) |> Exth.inspect("shared_secret xor nonce")

    # Sign xor'd secret
    {signature, _, _, recovery_id} = ExthCrypto.Signature.sign_digest(shared_secret_xor_nonce, my_ephemeral_private_key)

    # Build an auth message to send over the wire
    auth_msg = %AuthMsgV4{
      signature: signature <> :binary.encode_unsigned(recovery_id),
      remote_public_key: my_static_public_key,
      remote_nonce: nonce,
      remote_version: @protocol_version
    }

    # Return auth_msg and my new key pair
    {auth_msg, my_ephemeral_keypair, nonce}
  end

  @doc """
  Builds a response for an incoming authentication message.

  ## Examples

      iex> ExWire.Handshake.build_ack_resp(ExthCrypto.Test.public_key(:key_c), ExthCrypto.Test.init_vector())
      %ExWire.Handshake.Struct.AckRespV4{
        remote_ephemeral_public_key: <<4, 146, 201, 161, 205, 19, 177, 147, 33, 107, 190, 144, 81, 145, 173, 83, 20, 105, 150, 114, 196, 249, 143, 167, 152, 63, 225, 96, 184, 86, 203, 38, 134, 241, 40, 152, 74, 34, 68, 233, 204, 91, 240, 208, 254, 62, 169, 53, 201, 248, 156, 236, 34, 203, 156, 75, 18, 121, 162, 104, 3, 164, 156, 46, 186>>,
        remote_nonce: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>,
        remote_version: 4
      }
  """
  @spec build_ack_resp(ExthCrypto.Key.public_key, binary() | nil) :: AckRespV4.t
  def build_ack_resp(remote_ephemeral_public_key, nonce \\ nil) do
    # Generate nonce unless given
    nonce = if nonce, do: nonce, else: ExthCrypto.Math.nonce(@nonce_len)

    %AckRespV4{
      remote_nonce: nonce,
      remote_ephemeral_public_key: remote_ephemeral_public_key,
      remote_version: @protocol_version
    }
  end

  @doc """
  Given an incoming message, let's try to accept it as an ack resp. If that works,
  we'll derive our secrets from it.

  # TODO: Add examples
  """
  @spec try_handle_ack(binary(), binary(), ExthCrypto.Key.private_key, binary(), String.t) :: {:ok, Secrets.t} | :invalid
  def try_handle_ack(ack_data, auth_data, my_ephemeral_private_key, my_nonce, host) do
    case ExWire.Handshake.read_ack_resp(ack_data, ExWire.private_key, host) do
      {:ok, %ExWire.Handshake.Struct.AckRespV4{
        remote_ephemeral_public_key: remote_ephemeral_public_key,
        remote_nonce: remote_nonce
      }} ->
        # We're the initiator, by definition since we got an ack resp.
        secrets = ExWire.Framing.Secrets.derive_secrets(
          my_ephemeral_private_key,
          remote_ephemeral_public_key,
          remote_nonce,
          my_nonce,
          auth_data,
          ack_data
        )

        {:ok, secrets}
      _ ->
        :invalid
    end
  end

  @doc """
  Give an incoming msg, let's try to accept it as an auth msg. If that works,
  we'll prepare an ack response to send back and derive our secrets.

  TODO: Add examples
  """
  @spec try_handle_auth(binary(), ExthCrypto.Key.key_pair, binary(), binary(), String.t) :: {:ok, binary(), Secrets.t} | :invalid
  def try_handle_auth(auth_data, {my_ephemeral_public_key, my_ephemeral_private_key}=my_ephemeral_key_pair, my_nonce, remote_id, host) do
    case ExWire.Handshake.read_auth_msg(auth_data, ExWire.private_key, host) do
      {:ok, %ExWire.Handshake.Struct.AuthMsgV4{
        signature: signature,
        remote_public_key: remote_public_key,
        remote_nonce: remote_nonce,
        remote_version: remote_version,
        remote_ephemeral_public_key: remote_ephemeral_public_key,
      }} ->
        # First, we'll build an ack, which we'll respond with to the remote peer
        ack_resp = ExWire.Handshake.build_ack_resp(remote_ephemeral_public_key: my_ephemeral_public_key, remote_version: remote_version)

        # TODO: Make this accurate
        {:ok, encoded_ack_resp} = ack_resp
          |> ExWire.Handshake.Struct.AckRespV4.serialize()
          |> ExWire.Handshake.EIP8.wrap_eip_8(remote_id, host, my_ephemeral_key_pair)

        # We have the auth, we can derive secrets already
        secrets = ExWire.Framing.Secrets.derive_secrets(
          my_ephemeral_private_key,
          remote_ephemeral_public_key,
          remote_nonce,
          my_nonce,
          auth_data,
          encoded_ack_resp
        )

        {:ok, ack_resp, secrets}
      _ ->
        :invalid
    end
  end

end