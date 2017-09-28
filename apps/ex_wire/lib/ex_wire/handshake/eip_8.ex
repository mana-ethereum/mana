defmodule ExWire.Handshake.EIP8 do
  @moduledoc """
  Handles wrapping and unwrapping messages according to the specification in
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).
  """

  require Logger

  # Amount of bytes added when encrypting with ECIES.
  # EIP Question: This is magic, isn't it? Definitely magic.
  @ecies_overhead 113
  @protocol_version 4

  @doc """
  Wraps a message in EIP-8 encoding, according to
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).

  ## Examples

      iex> {:ok, bin} = ExWire.Handshake.EIP8.wrap_eip_8(["jedi", "knight"], ExthCrypto.Test.public_key, "1.2.3.4", ExthCrypto.Test.key_pair(:key_b), ExthCrypto.Test.init_vector, ExthCrypto.Test.init_vector(1, 100))
      iex> bin |> ExthCrypto.Math.bin_to_hex
      "00e6049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f102cb1de6abaaa6f731dbe4cd77135af3c6c48aaa361de5610e901a4b761b588aee253fa658c3a7f8f467b5b36381c197a0d6b5ac6f3c6beba5cd455bc9fe98d621707dcb9a51a4895040a1dcbd1a6a32af7d8d407f2a54c0346a28806e597f52b42a59404697f4e913fd38cd2bfecdac553b1987f1b61049f516053a5a1f8cdc9efae57748d98355864f59037e326e7ec9b2d947580"
  """
  @spec wrap_eip_8(ExRLP.t, ExthCrypto.Key.public_key, binary(), {ExthCrypto.Key.public_key, ExthCrypto.Key.private_key} | nil, Cipher.init_vector | nil, binary() | nil) :: {:ok, binary()} | {:error, String.t}
  def wrap_eip_8(rlp, her_static_public_key, remote_addr, my_ephemeral_key_pair \\ nil, init_vector \\ nil, padding \\ nil) do
    Logger.debug("[Network] Sending EIP8 Handshake to #{remote_addr}")

    padding = case padding do
      nil ->
        # Generate a random length of padding (this does not need to be secure)
        # EIP Question: is there a security flaw if this is not random?
        padding_length = Enum.random(100..300)

        # Generate a random padding (nonce), this probably doesn't need to be secure
        # EIP Question: why is this not just padded with zeros?
        ExthCrypto.Math.nonce(padding_length)
      padding -> padding
    end |> :binary.bin_to_list
    padding = ExthCrypto.Math.pad(<<>>, 100)

    # rlp.list(sig, initiator-pubk, initiator-nonce, auth-vsn)
    # EIP Question: Why is random appended at the end? Is this going to make it hard to upgrade the protocol?
    auth_body = ExRLP.encode(rlp ++ [@protocol_version, padding])

    # size of enc-auth-body, encoded as a big-endian 16-bit integer
    # EIP Question: It's insane we expect the protocol to know the size of the packet prior to encoding.
    auth_size_int = byte_size(auth_body) + @ecies_overhead
    auth_size = <<auth_size_int::integer-big-size(16)>>

    # ecies.encrypt(recipient-pubk, auth-body, auth-size)
    with {:ok, enc_auth_body} <- ExthCrypto.ECIES.encrypt(her_static_public_key, auth_body, <<>>, auth_size, my_ephemeral_key_pair, init_vector) do
      # size of enc-auth-body, encoded as a big-endian 16-bit integer
      enc_auth_body_size = byte_size(enc_auth_body)

      if enc_auth_body_size != auth_size_int do
        # The auth-size is hard coded, so the least we can do is verify
        {:error, "Invalid encoded body size"}
      else
        # auth-packet      = auth-size || enc-auth-body
        # EIP Question: Doesn't RLP already handle size definitions?
        {:ok, auth_size <> enc_auth_body}
      end
    end
  end

  @doc """
  Unwraps a message in EIP-8 encoding, according to
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).

  ## Examples

      iex> "00e6049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f102cb1de6abaaa6f731dbe4cd77135af3c6c48aaa361de5610e901a4b761b588aee253fa658c3a7f8f467b5b36381c197a0d6b5ac6f3c6beba5cd455bc9fe98d621707dcb9a51a4895040a1dcbd1a6a32af7d8d407f2a54c0346a28806e597f52b42a59404697f4e913fd38cd2bfecdac553b1987f1b61049f516053a5a1f8cdc9efae57748d98355864f59037e326e7ec9b2d947580" |> ExthCrypto.Math.hex_to_bin
      ...> |> ExWire.Handshake.EIP8.unwrap_eip_8(ExthCrypto.Test.private_key(:key_a), "1.2.3.4")
      {:ok,
       ["jedi", "knight", <<4>>,
        <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
          41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
          60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78,
          79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97,
          98, 99, 100>>]}
  """
  @spec unwrap_eip_8(binary(), ExthCrypto.Key.private_key, binary()) :: {:ok, RLP.t} | {:error, String.t}
  def unwrap_eip_8(encoded_packet, my_static_private_key, remote_addr) do
    Logger.debug("[Network] Received EIP8 Handshake from #{remote_addr}")

    case encoded_packet do
      <<auth_size::binary-size(2), ecies_encoded_message::binary()>> ->
        if :binary.decode_unsigned(auth_size) != byte_size(ecies_encoded_message) do
          {:error, "Invalid auth size"}
        else
          with {:ok, rlp_bin} <- ExthCrypto.ECIES.decrypt(my_static_private_key, ecies_encoded_message, <<>>, auth_size) do
            rlp = ExRLP.decode(rlp_bin)

            {:ok, rlp}
          end
        end
      _ ->
        {:error, "Invalid encoded packet"}
    end
  end
end