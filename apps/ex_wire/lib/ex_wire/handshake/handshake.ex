defmodule ExWire.Handshake do
  @moduledoc """
  Defines the protocols to complete an ECEIS handshake with a remote peer.

  Note: we've foll
  """

  require Logger

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

  # Amount of bytes added when encrypting with encryptECIES.
  # EIP Question: This is magic, isn't it?
  @ecies_overhead 113
  @protocol_version 4

  # RLPx v4 handshake auth (defined in EIP-8).
  defmodule AuthMsgV4 do
    defstruct [:signature, :initator_public_key, :nonce, :version, :tail]

    @type t :: %__MODULE__{
      signature: ExCrypto.signature,
      initator_public_key: ExCrypto.public_key,
      nonce: binary(),
      version: integer(),
      tail: binary()
    }

    @spec serialize(t) :: ExRLP.t
    def serialize(auth_msg) do
      [

      ]
    end

    @spec deserialize(ExRLP.t) :: t
    def deserialize(rlp) do
      [

      ]
    end
  end

  defmodule AuthRespV4 do
    # got plain?
    defstruct [:random_public_key, :nonce, :version, :tail]

    @type t :: %__MODULE__{
      random_public_key: ExCrypto.public_key,
      nonce: binary(),
      version: integer(),
      tail: binary()
    }

    @spec serialize(t) :: ExRLP.t
    def serialize(auth_resp) do
      [

      ]
    end

    @spec deserialize(ExRLP.t) :: t
    def deserialize(rlp) do
      [

      ]
    end
  end

  @doc """
  Wraps a message in EIP-8 encoding, according to
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).

  ## Examples

      iex> ExWire.Handshake.wrap_eip_8(["jedi", "knight"], ExCrypto.Test.public_key, "1.2.3.4", ExCrypto.Test.key_pair(:key_b), ExCrypto.Test.init_vector, ExCrypto.Test.init_vector(1, 100)) |> ExCrypto.Math.bin_to_hex
      "00e6049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10cb55410f8de25edda8138b141c18b4eef4cc55f66f09a84c33df952cd0ea636820f9d42e60dd10e26d224cfe704a481cdd72982073477bee9f10eb04b5fe6ab863e4873dbb61cd3215d3dc32b2dff59105f248ce6ba768341c5bfcbb62a8729dc8d3e6cf8dd91599125760c74014c8bb9397d93b5e90c578baeea47f969cbcd6a836030d2835826110fc037e6cc5a3553894fb3e2e"
  """
  @spec wrap_eip_8(ExRLP.t, ExCrypto.public_key, binary(), {ExCrypto.public_key, ExCrypto.private_key} | nil, Cipher.init_vector | nil, binary() | nil) :: {:ok, binary()} | {:error, String.t}
  def wrap_eip_8(rlp, her_static_public_key, remote_addr, my_ephemeral_key_pair \\ nil, init_vector \\ nil, padding \\ nil) do
    Logger.debug("[Network] Sending EIP8 Handshake to #{remote_addr}")

    padding = case padding do
      nil ->
        # Generate a random length of padding (this does not need to be secure)
        # EIP Question: is there a security flaw if this is not random?
        padding_length = Enum.random(100..300)

        # Generate a random padding (nonce), this probably doesn't need to be secure
        # EIP Question: why is this not just padded with zeros?
        ExCrypto.Math.nonce(padding_length)
      padding -> padding
    end

    # rlp.list(sig, initiator-pubk, initiator-nonce, auth-vsn)
    # EIP Question: Why is random appended at the end? Is this going to make it hard to upgrade the protocol?
    auth_body = ExRLP.encode(rlp ++ [@protocol_version, padding])

    # size of enc-auth-body, encoded as a big-endian 16-bit integer
    # EIP Question: It's insane we expect the protocol to know the size of the packet prior to encoding.
    auth_size_int = byte_size(auth_body) + @ecies_overhead
    auth_size = <<auth_size_int::integer-big-size(16)>>

    # ecies.encrypt(recipient-pubk, auth-body, auth-size)
    with {:ok, enc_auth_body} <- ExCrypto.ECIES.encrypt(her_static_public_key, auth_body, <<>>, auth_size, my_ephemeral_key_pair, init_vector) do
      # size of enc-auth-body, encoded as a big-endian 16-bit integer
      enc_auth_body_size = byte_size(enc_auth_body)

      if enc_auth_body_size != auth_size_int do
        # The auth-size is hard coded, so the least we can do is verify
        {:error, "Invalid encoded body size"}
      else
        # auth-packet      = auth-size || enc-auth-body
        # EIP Question: Doesn't RLP already handle size definitions?
        auth_size <> enc_auth_body
      end
    end
  end

  @doc """
  Unwraps a message in EIP-8 encoding, according to
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).

  ## Examples

      iex> "00e6049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10cb55410f8de25edda8138b141c18b4eef4cc55f66f09a84c33df952cd0ea636820f9d42e60dd10e26d224cfe704a481cdd72982073477bee9f10eb04b5fe6ab863e4873dbb61cd3215d3dc32b2dff59105f248ce6ba768341c5bfcbb62a8729dc8d3e6cf8dd91599125760c74014c8bb9397d93b5e90c578baeea47f969cbcd6a836030d2835826110fc037e6cc5a3553894fb3e2e" |> ExCrypto.Math.hex_to_bin
      ...> |> ExWire.Handshake.read_eip_8(ExCrypto.Test.private_key(:key_a), "1.2.3.4")
      {:ok, ["jedi", "knight"]}
  """
  @spec read_eip_8(binary(), ExCrypto.private_key, binary()) :: {:ok, RLP.t} | {:error, String.t}
  def read_eip_8(encoded_packet, my_static_private_key, remote_addr) do
    Logger.debug("[Network] Received EIP8 Handshake from #{remote_addr}")

    case encoded_packet do
      <<auth_size::binary-size(2), ecies_encoded_message::binary()>> ->
        if :binary.decode_unsigned(auth_size) != byte_size(ecies_encoded_message) do
          {:error, "Invalid auth size"}
        else
          with {:ok, rlp_bin} <- ExCrypto.ECIES.decrypt(my_static_private_key, ecies_encoded_message, <<>>, auth_size) do
            rlp = ExRLP.decode(rlp_bin)

            # Drop nonce and version
            {_nonce, rlp} = List.pop_at(rlp, -1)
            {<<0x04>>, rlp} = List.pop_at(rlp, -1)

            {:ok, rlp}
          end
        end
      _ ->
        {:error, "Invalid encoded packet"}
    end

    # TODO: Write ack

    # self.auth_cipher.extend_from_slice(data);
    # let auth = ecies::decrypt(secret, &self.auth_cipher[0..2], &self.auth_cipher[2..])?;
    # let rlp = UntrustedRlp::new(&auth);
    # let signature: H520 = rlp.val_at(0)?;
    # let remote_public: Public = rlp.val_at(1)?;
    # let remote_nonce: H256 = rlp.val_at(2)?;
    # let remote_version: u64 = rlp.val_at(3)?;
    # self.set_auth(secret, &signature, &remote_public, &remote_nonce, remote_version)?;
    # self.write_ack_eip8(io)?;
    # Ok(())
  end

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
  # @spec make_auth_msg(ExCrypto.private_key, token) :: {:ok, AuthMsgV4.t} | {:error, String.t}
  # def make_auth_msg(node_id, token) do
  #   my_ephemeral_private_key = .. #

  #   with {:ok, public_key} <- Crypto.node_id(private_key) do
  #     version = <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05>>
  #     token_flag = <<0x00>>

  #     initiator_nonce = ExCrypto.Math.nonce(24) # TODO: Shalen
  #     initiator_nonce_data = nonce <> version
  #     static_shared_secret = ExCrypto.ECDH(my_static_private_key, her_static_public_key)
  #     initator_sig = ExCrypto.Signature.sign(static_shared_secret ^ initiator_nonce_data, my_ephemeral_private_key)
  #     auth_msg_initiator =
  #       initator_sig <>
  #       sha3(my_ephemeral_public_key) <>
  #       my_static_public_key <>
  #       nonce <>
  #       version <>
  #       token_flag

  #     # TODO: Add optional params such as my_ephemeral_key_pair or init_vector?
  #     enc_auth_msg_initiator = ExCrypto.ECIES.encrypt(her_static_public_key, auth_msg_initiator, <<>>, <<>>)

  #   end
  # end


  @doc """
  After dailing a connection, perform handshake to generate secure connection.

  # TODO: Conn?
  # TODO: Token?

  """
  # @spec initiate_connection(conn, ExCrypto.private_key, ExCrypto.public_key, ExWire.node_id, token) :: {:ok, Secrets.t} | {:error, String.t}
  # def initiate_connection(conn, my_static_private_key, her_static_public_key, node_id, token) do
  #   handshake = %Handshake{
  #     initiator: true,
  #     remote_id: node_id,
  #   }
    





  # end

end