defmodule ExWire.Handshake.EIP8 do
  @moduledoc """
  Handles wrapping and unwrapping messages according to the specification in
  [Ethereum EIP-8](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md).

  TODO: How do we handle random padding?
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

      iex> {:ok, bin} = ExWire.Handshake.EIP8.wrap_eip_8(["jedi", "knight"], ExthCrypto.Test.public_key, ExthCrypto.Test.key_pair(:key_b), ExthCrypto.Test.init_vector)
      iex> bin |> ExthCrypto.Math.bin_to_hex
      "00e6049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f102cb1de6abaaa6f731dbe4cd77135af3c6c49a8a065db5017e108aebc6db886a1f242e876982f69985e62412d240107652d4a78e5d7e3989d74fd7f97b3c4a34d2736ee8a912f7ea23c3327f0ed9b9d15b7999644b6e00a440eebc24da9dabb6412f4c6573d2a18c6678ad689e3b1849a33d0fa1c7ffb43a4033428646258196942e611ea2bf31b983e98356f2f57951c4aebb8dd54"
  """
  @spec wrap_eip_8(
          ExRLP.t(),
          ExthCrypto.Key.public_key(),
          {ExthCrypto.Key.public_key(), ExthCrypto.Key.private_key()} | nil,
          ExthCrypto.Cipher.init_vector() | nil
        ) :: {:ok, binary()} | {:error, String.t()}
  def wrap_eip_8(
        rlp,
        her_static_public_key,
        my_ephemeral_key_pair \\ nil,
        init_vector \\ nil
      ) do
    # According to EIP-8, we add padding to prevent length detection attacks. Thus, it should be
    # acceptable to pad with zero instead of random data. We opt for padding with zeros.
    padding = ExthCrypto.Math.pad(<<>>, 100)

    # rlp.list(sig, initiator-pubk, initiator-nonce, auth-vsn)
    # EIP Question: Why is random appended at the end? Is this going to make it hard to upgrade the protocol?
    auth_body = ExRLP.encode(rlp ++ [@protocol_version, padding])

    # size of enc-auth-body, encoded as a big-endian 16-bit integer
    # EIP Question: It's insane we expect the protocol to know the size of the packet prior to encoding.
    auth_size_int = byte_size(auth_body) + @ecies_overhead
    auth_size = <<auth_size_int::integer-big-size(16)>>

    # ecies.encrypt(recipient-pubk, auth-body, auth-size)
    with {:ok, enc_auth_body} <-
           ExthCrypto.ECIES.encrypt(
             her_static_public_key,
             auth_body,
             <<>>,
             auth_size,
             my_ephemeral_key_pair,
             init_vector
           ) do
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
      ...> |> ExWire.Handshake.EIP8.unwrap_eip_8(ExthCrypto.Test.private_key(:key_a))
      {:ok,
       ["jedi", "knight", <<4>>,
        <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
          22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
          41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
          60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78,
          79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97,
          98, 99, 100>>],
        <<0, 230, 4, 152, 113, 235, 8, 21, 103, 130, 50, 103, 89, 42, 186, 200, 236,
          158, 159, 221, 253, 236, 231, 144, 26, 21, 242, 51, 181, 63, 48, 77, 120,
          96, 104, 108, 33, 96, 27, 161, 167, 245, 102, 128, 226, 45, 10, 192, 62,
          204, 208, 142, 73, 100, 105, 81, 76, 37, 174, 29, 94, 85, 243, 145, 193,
          149, 111, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 44, 177,
          222, 106, 186, 170, 111, 115, 29, 190, 76, 215, 113, 53, 175, 60, 108, 72,
          170, 163, 97, 222, 86, 16, 233, 1, 164, 183, 97, 181, 136, 174, 226, 83,
          250, 101, 140, 58, 127, 143, 70, 123, 91, 54, 56, 28, 25, 122, 13, 107, 90,
          198, 243, 198, 190, 186, 92, 212, 85, 188, 159, 233, 141, 98, 23, 7, 220,
          185, 165, 26, 72, 149, 4, 10, 29, 203, 209, 166, 163, 42, 247, 216, 212, 7,
          242, 165, 76, 3, 70, 162, 136, 6, 229, 151, 245, 43, 66, 165, 148, 4, 105,
          127, 78, 145, 63, 211, 140, 210, 191, 236, 218, 197, 83, 177, 152, 127, 27,
          97, 4, 159, 81, 96, 83, 165, 161, 248, 205, 201, 239, 174, 87, 116, 141,
          152, 53, 88, 100, 245, 144, 55, 227, 38, 231, 236, 155, 45, 148, 117, 128>>,
        ""}
  """
  @spec unwrap_eip_8(binary(), ExthCrypto.Key.private_key()) ::
          {:ok, ExRLP.t(), binary(), binary()} | {:error, String.t()}
  def unwrap_eip_8(encoded_packet, my_static_private_key) do
    <<auth_size_int::size(16), _::binary()>> = encoded_packet

    case encoded_packet do
      <<auth_size::binary-size(2), ecies_encoded_message::binary-size(auth_size_int),
        frame_rest::binary()>> ->
        with {:ok, rlp_bin} <-
               ExthCrypto.ECIES.decrypt(
                 my_static_private_key,
                 ecies_encoded_message,
                 <<>>,
                 auth_size
               ) do
          rlp = ExRLP.decode(rlp_bin)

          {:ok, rlp, auth_size <> ecies_encoded_message, frame_rest}
        end

      _ ->
        {:error, "Invalid encoded packet"}
    end
  end
end
