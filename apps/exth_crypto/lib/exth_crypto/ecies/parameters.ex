defmodule ExthCrypto.ECIES.Parameters do
  @moduledoc """
  Returns one set of the Standard ECIES parameters:

  * ECIES using AES128 and HMAC-SHA-256-16
  * ECIES using AES256 and HMAC-SHA-256-32
  * ECIES using AES256 and HMAC-SHA-384-48
  * ECIES using AES256 and HMAC-SHA-512-64
  """

  defstruct mac: nil,
            hasher: nil,
            cipher: nil,
            key_len: nil

  @type t :: %__MODULE__{
          mac: :crypto.hash_algorithms(),
          hasher: ExthCrypto.Hash.hash_type(),
          cipher: ExthCrypto.Cipher.cipher(),
          key_len: integer()
        }

  @doc """
  Returns curve parameters for ECIES with AES-256 symmetric
  encryption and SHA-256 hash.
  """
  @spec ecies_aes128_sha256() :: t
  def ecies_aes128_sha256 do
    %__MODULE__{
      mac: :sha256,
      hasher: {&ExthCrypto.Hash.SHA.sha256/1, nil, 32},
      cipher: {ExthCrypto.AES, ExthCrypto.AES.block_size(), :ctr},
      key_len: 16
    }
  end

  @doc """
  Returns curve parameters for ECIES with AES-256 symmetric
  encryption and SHA-256 hash.
  """
  @spec ecies_aes256_sha256() :: t
  def ecies_aes256_sha256 do
    %__MODULE__{
      mac: :sha256,
      hasher: {&ExthCrypto.Hash.SHA.sha256/1, nil, 32},
      cipher: {ExthCrypto.AES, ExthCrypto.AES.block_size(), :ctr},
      key_len: 32
    }
  end

  @doc """
  Returns curve parameters for ECIES with AES-256 symmetric
  encryption and SHA-384 hash.
  """
  @spec ecies_aes256_sha384() :: t
  def ecies_aes256_sha384 do
    %__MODULE__{
      mac: :sha256,
      hasher: {&ExthCrypto.Hash.SHA.sha384/1, nil, 48},
      cipher: {ExthCrypto.AES, ExthCrypto.AES.block_size(), :ctr},
      key_len: 32
    }
  end

  @doc """
  Returns curve parameters for ECIES with AES-256 symmetric
  encryption and SHA-512 hash.
  """
  @spec ecies_aes256_sha512() :: t
  def ecies_aes256_sha512 do
    %__MODULE__{
      mac: :sha256,
      hasher: {&ExthCrypto.Hash.SHA.sha512/1, nil, 64},
      cipher: {ExthCrypto.AES, ExthCrypto.AES.block_size(), :ctr},
      key_len: 32
    }
  end

  @doc """
  Returns the block size of a given set of ECIES params.

  ## Examples

      iex> ExthCrypto.ECIES.Parameters.block_size(ExthCrypto.ECIES.Parameters.ecies_aes256_sha512)
      32
  """
  @spec block_size(t) :: integer()
  def block_size(params) do
    {_, block_size, _args} = params.cipher

    block_size
  end

  @doc """
  Returns the hash len of a given set of ECIES params.

  ## Examples

      iex> ExthCrypto.ECIES.Parameters.hash_len(ExthCrypto.ECIES.Parameters.ecies_aes256_sha256)
      32

      iex> ExthCrypto.ECIES.Parameters.hash_len(ExthCrypto.ECIES.Parameters.ecies_aes256_sha512)
      64
  """
  @spec hash_len(t) :: integer()
  def hash_len(params) do
    # Get size of hash cipher
    {_, _, hash_len} = params.hasher

    hash_len
  end
end
