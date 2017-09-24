defmodule ExCrypto.Cipher do
  @moduledoc """
  Module for symmetric encryption.
  """

  @type cipher :: {atom(), integer()}
  @type plaintext :: iodata()
  @type ciphertext :: binary()
  @type init_vector :: binary()

  @doc """
  Encrypts the given plaintext for the given block cipher.

  ## Examples

      iex> ExCrypto.Cipher.encrypt("hi", ExCrypto.Test.public_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size})
      <<>>
  """
  @spec encrypt(plaintext, ExCrypto.public_key, init_vector, cipher) :: ciphertext
  def encrypt(plaintext, public_key, init_vector \\ nil, {mod, block_size} = _cipher) do
    cipher_iv = case init_vector do
      nil -> generate_init_vector(block_size)
      init_vector -> init_vector
    end

    mod.encrypt(plaintext, public_key, cipher_iv)
  end

  @doc """
  Decrypts the given ciphertext from the given block cipher.

  ## Examples

      iex> ExCrypto.Cipher.decrypt("hi", ExCrypto.Test.public_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size})
      <<>>
  """
  @spec decrypt(ciphertext, ExCrypto.private_key, init_vector, cipher) :: plaintext
  def decrypt(ciphertext, private_key, init_vector, {mod, _block_size} = _cipher) do
    mod.decrypt(ciphertext, private_key, init_vector)
  end

  @doc """
  Generate a random initialization vector for the given type of cipher.

  ## Examples

      iex> ExCrypto.Cipher.generate_init_vector(32) |> byte_size
      32

      iex> ExCrypto.Cipher.generate_init_vector(32) == ExCrypto.Cipher.generate_iv(32)
      false
  """
  @spec generate_init_vector(integer()) :: init_vector
  def generate_init_vector(block_size) do
    :crypto.strong_rand_bytes(block_size)
  end
end