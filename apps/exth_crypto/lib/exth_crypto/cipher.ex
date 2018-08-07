defmodule ExthCrypto.Cipher do
  @moduledoc """
  Module for symmetric encryption.
  """

  @type mode :: :cbc | :ctr | :ecb
  @type cipher :: {atom(), integer(), mode}
  @type plaintext :: iodata()
  @type ciphertext :: binary()
  @type init_vector :: binary()
  @opaque stream :: :crypto.ctr_state()

  @doc """
  Encrypts the given plaintext for the given block cipher.

  ## Examples

      iex> ExthCrypto.Cipher.encrypt("execute order 66", ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :cbc}) |> ExthCrypto.Math.bin_to_hex
      "4f0150273733727f994754fee054df7e18ec169892db5ba973cf8580b898651b"

      iex> ExthCrypto.Cipher.encrypt("execute order 66", ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :ctr}) |> ExthCrypto.Math.bin_to_hex
      "2a7935444247175ff635309b9274e948"

      iex> ExthCrypto.Cipher.encrypt("execute order 66", ExthCrypto.Test.symmetric_key, {ExthCrypto.AES, ExthCrypto.AES.block_size, :ecb}) |> ExthCrypto.Math.bin_to_hex
      "a73c5576667b7b43a23a9fd930b5465d637a44d08bf702881a8d4e6a5d4944b5"
  """
  @spec encrypt(plaintext, ExthCrypto.Key.symmetric_key(), init_vector, cipher) :: ciphertext
  def encrypt(plaintext, symmetric_key, init_vector, {mod, _block_size, mode}) do
    mod.encrypt(plaintext, mode, symmetric_key, init_vector)
  end

  @spec encrypt(plaintext, ExthCrypto.Key.symmetric_key(), cipher) :: ciphertext
  def encrypt(plaintext, symmetric_key, {mod, _block_size, mode}) do
    mod.encrypt(plaintext, mode, symmetric_key)
  end

  @doc """
  Decrypts the given ciphertext from the given block cipher.

  ## Examples

      iex> "4f0150273733727f994754fee054df7e18ec169892db5ba973cf8580b898651b"
      ...> |> ExthCrypto.Math.hex_to_bin
      ...> |> ExthCrypto.Cipher.decrypt(ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :cbc})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "execute order 66"

      iex> "2a7935444247175ff635309b9274e948"
      ...> |> ExthCrypto.Math.hex_to_bin
      ...> |> ExthCrypto.Cipher.decrypt(ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :ctr})
      "execute order 66"

      iex> "a73c5576667b7b43a23a9fd930b5465d637a44d08bf702881a8d4e6a5d4944b5"
      ...> |> ExthCrypto.Math.hex_to_bin
      ...> |> ExthCrypto.Cipher.decrypt(ExthCrypto.Test.symmetric_key, {ExthCrypto.AES, ExthCrypto.AES.block_size, :ecb})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "execute order 66"
  """
  @spec decrypt(ciphertext, ExthCrypto.Key.symmetric_key(), init_vector, cipher) :: plaintext
  def decrypt(ciphertext, symmetric_key, init_vector, {mod, _block_size, mode}) do
    mod.decrypt(ciphertext, mode, symmetric_key, init_vector)
  end

  @spec decrypt(ciphertext, ExthCrypto.Key.symmetric_key(), cipher) :: plaintext
  def decrypt(ciphertext, symmetric_key, {mod, _block_size, mode}) do
    mod.decrypt(ciphertext, mode, symmetric_key)
  end

  @doc """
  Generate a random initialization vector for the given type of cipher.

  ## Examples

      iex> ExthCrypto.Cipher.generate_init_vector(32) |> byte_size
      32

      iex> ExthCrypto.Cipher.generate_init_vector(32) == ExthCrypto.Cipher.generate_init_vector(32)
      false
  """
  @spec generate_init_vector(integer()) :: init_vector
  def generate_init_vector(block_size) do
    :crypto.strong_rand_bytes(block_size)
  end
end
