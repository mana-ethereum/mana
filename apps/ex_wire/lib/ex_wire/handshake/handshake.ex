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

  # @handshake_timeout 5000
  @protocol_version 4
  @nonce_len 32

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
        auth_msg.remote_public_key |> ExthCrypto.Key.der_to_raw,
        auth_msg.remote_nonce,
        auth_msg.remote_version |> :binary.encode_unsigned
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
        remote_version: (if is_binary(remote_version), do: :binary.decode_unsigned(remote_version), else: remote_version),
      }
    end

    @doc """
    Sets the remote ephemeral public key for a given auth msg, based on our secret
    and the keys passed from remote.

    # TODO: Test
    # TODO: Multiple possible values and no recovery key?
    """
    @spec set_remote_ephemeral_public_key(t, ExthCrypto.Key.private_key) :: t
    def set_remote_ephemeral_public_key(auth_msg, my_static_private_key) do
      shared_secret = ECDH.generate_shared_secret(my_static_private_key, auth_msg.remote_public_key)
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
        auth_resp.remote_version |> :binary.encode_unsigned,
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
        remote_version: (if is_binary(remote_version), do: :binary.decode_unsigned(remote_version), else: remote_version),
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
  def read_auth_msg(encoded_auth, my_static_private_key, remote_addr) do
    case EIP8.unwrap_eip_8(encoded_auth, my_static_private_key, "1.2.3.4") do
      {:ok, rlp} ->
        # unwrap eip-8
        auth_msg =
          rlp
          |> ExWire.Handshake.AuthMsgV4.deserialize()
          |> ExWire.Handshake.AuthMsgV4.set_remote_ephemeral_public_key(my_static_private_key)

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
            |> ExWire.Handshake.AuthMsgV4.deserialize()
            |> ExWire.Handshake.AuthMsgV4.set_remote_ephemeral_public_key(my_static_private_key)

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
    case EIP8.unwrap_eip_8(encoded_ack, my_static_private_key, "1.2.3.4") do
      {:ok, rlp} ->
        # unwrap eip-8
        ack_resp =
          rlp
          |> ExWire.Handshake.AckRespV4.deserialize()

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
            |> ExWire.Handshake.AckRespV4.deserialize()

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
        %ExWire.Handshake.AuthMsgV4{
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
        }
      }
  """
  @spec build_auth_msg(ExthCrypto.Key.public_key, ExthCrypto.Key.private_key, ExthCrypto.Key.public_key, binary() | nil, ExthCrypto.Key.key_pair | nil) :: {AuthMsgV4.t, ExthCrypto.Key.key_pair}
  def build_auth_msg(my_static_public_key, my_static_private_key, her_static_public_key, nonce \\ nil, my_ephemeral_keypair \\ nil) do

    # Geneate a random ephemeral keypair
    my_ephemeral_keypair = if my_ephemeral_keypair, do: my_ephemeral_keypair, else: ECDH.new_ecdh_keypair()

    {my_ephemeral_public_key, _my_ephemeral_private_key} = my_ephemeral_keypair

    # Determine DH shared secret
    shared_secret = ECDH.generate_shared_secret(my_static_private_key, her_static_public_key)

    # Build a nonce unless given
    nonce = if nonce, do: nonce, else: ExthCrypto.Math.nonce(@nonce_len)

    # XOR shared-secret and nonce
    shared_secret_xor_nonce = :crypto.exor(shared_secret, nonce)

    # Sign xor'd secret
    {signature, _, _, _} = ExthCrypto.Signature.sign_digest(shared_secret_xor_nonce, my_ephemeral_public_key)

    # Build an auth message to send over the wire
    auth_msg = %AuthMsgV4{
      signature: signature,
      remote_public_key: my_static_public_key,
      remote_nonce: nonce,
      remote_version: @protocol_version
    }

    # Return auth_msg and my new key pair
    {auth_msg, my_ephemeral_keypair}
  end

  @doc """
  Builds a response for an incoming authentication message.

  ## Examples

      iex> ExWire.Handshake.build_ack_resp(ExthCrypto.Test.public_key(:key_c), ExthCrypto.Test.init_vector())
      %ExWire.Handshake.AckRespV4{
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