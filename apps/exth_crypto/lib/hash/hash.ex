defmodule ExCrypto.Hash do
  @moduledoc """
  A variety of functions to handle one-way hashing functions as
  defined by Ethereum.
  """

  @type hash_algorithm :: atom()
  @type hash :: binary()
  @type hasher :: (binary() -> binary())
  @type hash_type :: {hasher, integer() | nil, integer()}

  @doc """
  Returns a list of supported hash algorithms.
  """
  @hash_algorithms [ :md5, :ripemd160, :sha, :sha224, :sha256, :sha384, :sha512 ]
  @spec hash_algorithms() :: [hash_algorithm]
  def hash_algorithms, do: @hash_algorithms

  @doc """
  The SHA1 hasher.
  """
  @spec sha1() :: ExCrypto.hash_type
  def sha1, do: {&ExCrypto.Hash.SHA.sha1/1, nil, 20}

  @doc """
  The KECCAK hasher, as defined by Ethereum.
  """
  @spec kec() :: ExCrpyto.hash_type
  def kec, do: {&ExCrypto.Hash.Keccak.kec/1, nil, 256}

  @doc """
  Runs the specified hash type on the given data.

  ## Examples

      iex> ExCrypto.Hash.hash("hi", ExCrypto.Hash.kec)
      <<>>

      iex> ExCrypto.Hash.hash("hi", ExCrypto.Hash.sha1)
      <<>>
  """
  @spec hash(iodata(), hash_type) :: hash
  def hash(data, {hash_fun, _, _}=_hasher) do
    hash_fun.(data)
  end

end