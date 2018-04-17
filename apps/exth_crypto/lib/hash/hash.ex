defmodule ExthCrypto.Hash do
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
  @spec sha1() :: ExthCrypto.hash_type
  def sha1, do: {&ExthCrypto.Hash.SHA.sha1/1, nil, 20}

  @doc """
  The KECCAK hasher, as defined by Ethereum.
  """
  @spec kec() :: ExCrpyto.hash_type
  def kec, do: {&ExthCrypto.Hash.Keccak.kec/1, nil, 256}

  @doc """
  Runs the specified hash type on the given data.

  ## Examples

      iex> ExthCrypto.Hash.hash("hello world", ExthCrypto.Hash.kec) |> ExthCrypto.Math.bin_to_hex
      "47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad"

      iex> ExthCrypto.Hash.hash("hello world", ExthCrypto.Hash.sha1) |> ExthCrypto.Math.bin_to_hex
      "2aae6c35c94fcfb415dbe95f408b9ce91ee846ed"
  """
  @spec hash(iodata(), hash_type) :: hash
  def hash(data, {hash_fun, _, _}=_hasher) do
    hash_fun.(data)
  end

end