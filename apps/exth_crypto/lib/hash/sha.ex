defmodule ExCrypto.Hash.SHA do
  @moduledoc """
  Helper functions for running Secure Hash Algorithm (SHA).
  """

  @doc """
  Computes the SHA-1 of a given input.

  ## Examples

      iex> ExCrypto.Hash.SHA.sha1("test")
      <<>>
  """
  @spec sha1(binary()) :: <<_::160>>
  def sha1(data) do
    :crypto.hash(:sha, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 256 bits.

  ## Examples

      iex> ExCrypto.Hash.SHA.sha256("test")
      <<>>
  """
  @spec sha256(binary()) :: <<_::256>>
  def sha256(data) do
    :crypto.hash(:sha256, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 384 bits.

  ## Examples

      iex> ExCrypto.Hash.SHA.sha384("test")
      <<>>
  """
  @spec sha384(binary()) :: <<_::384>>
  def sha384(data) do
    :crypto.hash(:sha384, data)
  end

  @doc """
  Computes the SHA-2 of a given input outputting 512 bits.

  ## Examples

      iex> ExCrypto.Hash.SHA.sha512("test")
      <<>>
  """
  @spec sha512(binary()) :: <<_::512>>
  def sha512(data) do
    :crypto.hash(:sha512, data)
  end
end