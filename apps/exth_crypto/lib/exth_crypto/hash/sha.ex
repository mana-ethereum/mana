defmodule ExthCrypto.Hash.SHA do
  @moduledoc """
  Helper functions for running Secure Hash Algorithm (SHA).
  """

  @doc """
  Computes the SHA-1 of a given input.

  ## Examples

      iex> ExthCrypto.Hash.SHA.sha1("The quick brown fox jumps over the lazy dog") |> ExthCrypto.Math.bin_to_hex
      "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"

      iex> ExthCrypto.Hash.SHA.sha1("") |> ExthCrypto.Math.bin_to_hex
      "da39a3ee5e6b4b0d3255bfef95601890afd80709"
  """
  @spec sha1(binary()) :: <<_::160>>
  def sha1(data) do
    :crypto.hash(:sha, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 256 bits.

  ## Examples

      iex> ExthCrypto.Hash.SHA.sha256("") |> ExthCrypto.Math.bin_to_hex
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  """
  @spec sha256(binary()) :: <<_::256>>
  def sha256(data) do
    :crypto.hash(:sha256, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 384 bits.

  ## Examples

      iex> ExthCrypto.Hash.SHA.sha384("") |> ExthCrypto.Math.bin_to_hex
      "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"
  """
  @spec sha384(binary()) :: <<_::384>>
  def sha384(data) do
    :crypto.hash(:sha384, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 512 bits.

  ## Examples

      iex> ExthCrypto.Hash.SHA.sha512("") |> ExthCrypto.Math.bin_to_hex
      "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  """
  @spec sha512(binary()) :: <<_::512>>
  def sha512(data) do
    :crypto.hash(:sha512, data)
  end
end
