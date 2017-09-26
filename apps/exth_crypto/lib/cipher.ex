defmodule ExthCrypto.Cipher do
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

      iex> ExthCrypto.Cipher.encrypt("execute order 66", ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :cbc}) |> ExthCrypto.Math.bin_to_hex
      "4f0150273733727f994754fee054df7e18ec169892db5ba973cf8580b898651b"

      iex> ExthCrypto.Cipher.encrypt("execute order 66", ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector, {ExthCrypto.AES, ExthCrypto.AES.block_size, :ctr}) |> ExthCrypto.Math.bin_to_hex
      "2a7935444247175ff635309b9274e948"
  """
  @spec encrypt(plaintext, ExthCrypto.symmetric_key, init_vector, cipher) :: ciphertext
  def encrypt(plaintext, symmetric_key, init_vector, {mod, _block_size, mode} = _cipher) do
    mod.encrypt(plaintext, mode, symmetric_key, init_vector)
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
  """
  @spec decrypt(ciphertext, ExthCrypto.symmetric_key, init_vector, cipher) :: plaintext
  def decrypt(ciphertext, symmetric_key, init_vector, {mod, _block_size, mode} = _cipher) do
    mod.decrypt(ciphertext, mode, symmetric_key, init_vector)
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