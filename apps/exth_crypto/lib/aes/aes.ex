defmodule ExCrypto.AES do
  @moduledoc """
  Defines standard functions for use with AES symmetric cryptography.
  """

  @cipher_type :aes_ecb
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

      iex> public_key = <<1>>
      iex> ExCrypto.AES.encrypt("cat dog", public_key, "init")
      <<1>>
  """
  @spec encrypt(ExCrypto.Cipher.plaintext, ExCrypto.public_key, ExCrypto.Cipher.iv) :: ExCrypto.Cipher.ciphertext
  def encrypt(plaintext, public_key, iv) do
    :crypto.block_encrypt(@cipher_type, public_key, iv, plaintext)
  end

  @doc """
  Decrypts the given binary with the given private key.

  ## Examples

      iex> private_key = <<2>>
      iex> ExCrypto.AES.decrypt(<<1>>, private_key, "init")
      "cat dog"
  """
  @spec decrypt(ExCrypto.Cipher.ciphertext, ExCrypto.private_key, ExCrypto.Cipher.iv) :: ExCrypto.Cipher.plaintext
  def decrypt(ciphertext, private_key, iv) do
    :crypto.block_decrypt(@cipher_type, private_key, iv, ciphertext)
  end
end