defmodule ExCrypto.AES do
  @moduledoc """
  Defines standard functions for use with AES symmetric cryptography.
  """

  @cipher_type :aes_cbc
  @block_size 32

  @doc """
  Returns the blocksize for AES encryption.

  ## Examples

      iex> ExCrypto.AES.block_size
      32
  """
  @spec block_size :: integer()
  def block_size, do: @block_size

  @doc """
  Encrypts a given binary with the given public key.

  ## Examples

      iex> ExCrypto.AES.encrypt("obi wan", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector)
      <<86, 16, 7, 47, 97, 219, 8, 46, 16, 170, 70, 100, 131, 140, 241, 28>>

      iex> ExCrypto.AES.encrypt("obi wan", ExCrypto.Test.symmetric_key(:key_b), ExCrypto.Test.init_vector)
      <<219, 181, 173, 235, 88, 139, 229, 61, 172, 142, 36, 195, 83, 203, 237, 39>>

      iex> ExCrypto.AES.encrypt("obi wan", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector(2))
      <<134, 126, 59, 64, 83, 197, 85, 40, 155, 178, 52, 165, 27, 190, 60, 170>>

      iex> ExCrypto.AES.encrypt("jedi knight", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector)
      <<54, 252, 188, 111, 221, 182, 65, 54, 77, 143, 127, 188, 176, 178, 50, 160>>

      iex> ExCrypto.AES.encrypt("Did you ever hear the story of Darth Plagueis The Wise? I thought not.", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector) |> ExCrypto.Math.bin_to_hex
      "3ee326e03303a303df6eac828b0bdc8ed67254b44a6a79cd0082bc245977b0e7d4283d63a346744d2f1ecaafca8be906d9f3d27db914d80b601d7e0c598418380e5fe2b48c0e0b8454c6d251f577f28f"
  """
  @spec encrypt(ExCrypto.Cipher.plaintext, ExCrypto.symmetric_key, ExCrypto.Cipher.init_vector) :: ExCrypto.Cipher.ciphertext
  def encrypt(plaintext, symmetric_key, init_vector) do
    padding_bits = ( 16 - rem(byte_size(plaintext), 16) ) * 8

    :crypto.block_encrypt(@cipher_type, symmetric_key, init_vector, <<0::size(padding_bits)>> <> plaintext)
  end

  @doc """
  Decrypts the given binary with the given private key.

  ## Examples

      iex> <<86, 16, 7, 47, 97, 219, 8, 46, 16, 170, 70, 100, 131, 140, 241, 28>>
      ...> |> ExCrypto.AES.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<219, 181, 173, 235, 88, 139, 229, 61, 172, 142, 36, 195, 83, 203, 237, 39>>
      ...> |> ExCrypto.AES.decrypt(ExCrypto.Test.symmetric_key(:key_b), ExCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<134, 126, 59, 64, 83, 197, 85, 40, 155, 178, 52, 165, 27, 190, 60, 170>>
      ...> |> ExCrypto.AES.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector(2))
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<54, 252, 188, 111, 221, 182, 65, 54, 77, 143, 127, 188, 176, 178, 50, 160>>
      ...> |> ExCrypto.AES.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0>> <> "jedi knight"

      iex> "3ee326e03303a303df6eac828b0bdc8ed67254b44a6a79cd0082bc245977b0e7d4283d63a346744d2f1ecaafca8be906d9f3d27db914d80b601d7e0c598418380e5fe2b48c0e0b8454c6d251f577f28f"
      ...> |> ExCrypto.Math.hex_to_bin
      ...> |> ExCrypto.AES.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "Did you ever hear the story of Darth Plagueis The Wise? I thought not."
  """
  @spec decrypt(ExCrypto.Cipher.ciphertext, ExCrypto.symmetric_key, ExCrypto.Cipher.init_vector) :: ExCrypto.Cipher.plaintext
  def decrypt(ciphertext, symmetric_key, init_vector) do
    :crypto.block_decrypt(@cipher_type, symmetric_key, init_vector, ciphertext)
  end
end