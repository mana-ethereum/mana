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

      iex> ExCrypto.Cipher.encrypt("execute order 66", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size, :cbc}) |> ExCrypto.Math.bin_to_hex
      "4f0150273733727f994754fee054df7e18ec169892db5ba973cf8580b898651b"

      iex> ExCrypto.Cipher.encrypt("execute order 66", ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size, :ctr}) |> ExCrypto.Math.bin_to_hex
      "2a7935444247175ff635309b9274e948"
  """
  @spec encrypt(plaintext, ExCrypto.symmetric_key, init_vector, cipher) :: ciphertext
  def encrypt(plaintext, symmetric_key, init_vector, {mod, _block_size, mode} = _cipher) do
    mod.encrypt(plaintext, mode, symmetric_key, init_vector)
  end

  @doc """
  Decrypts the given ciphertext from the given block cipher.

  ## Examples

      iex> "4f0150273733727f994754fee054df7e18ec169892db5ba973cf8580b898651b"
      ...> |> ExCrypto.Math.hex_to_bin
      ...> |> ExCrypto.Cipher.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size, :cbc})
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "execute order 66"

      iex> "2a7935444247175ff635309b9274e948"
      ...> |> ExCrypto.Math.hex_to_bin
      ...> |> ExCrypto.Cipher.decrypt(ExCrypto.Test.symmetric_key, ExCrypto.Test.init_vector, {ExCrypto.AES, ExCrypto.AES.block_size, :ctr})
      "execute order 66"
  """
  @spec decrypt(ciphertext, ExCrypto.symmetric_key, init_vector, cipher) :: plaintext
  def decrypt(ciphertext, symmetric_key, init_vector, {mod, _block_size, mode} = _cipher) do
    mod.decrypt(ciphertext, mode, symmetric_key, init_vector)
  end

  @doc """
  Generate a random initialization vector for the given type of cipher.

  ## Examples

      iex> ExCrypto.Cipher.generate_init_vector(32) |> byte_size
      32

      iex> ExCrypto.Cipher.generate_init_vector(32) == ExCrypto.Cipher.generate_init_vector(32)
      false
  """
  @spec generate_init_vector(integer()) :: init_vector
  def generate_init_vector(block_size) do
    :crypto.strong_rand_bytes(block_size)
  end
end