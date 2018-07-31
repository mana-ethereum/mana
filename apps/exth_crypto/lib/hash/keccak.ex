defmodule ExthCrypto.Hash.Keccak do
  @moduledoc """
  Simple wrapper for Keccak function for Ethereum.

  Note: This module defines KECCAK as defined by Ethereum, which differs slightly
  than that assigned as the new SHA-3 variant. For SHA-3, a few constants have
  been changed prior to adoption by NIST, but after adoption by Ethereum.
  """

  @type keccak_hash :: ExthCrypto.Hash.hash()
  @type keccak_mac :: {atom(), binary()}

  @doc """
  Returns the keccak sha256 of a given input.

  ## Examples

      iex> ExthCrypto.Hash.Keccak.kec("hello world")
      <<71, 23, 50, 133, 168, 215, 52, 30, 94, 151, 47, 198, 119, 40, 99,
        132, 248, 2, 248, 239, 66, 165, 236, 95, 3, 187, 250, 37, 76, 176,
        31, 173>>

      iex> ExthCrypto.Hash.Keccak.kec(<<0x01, 0x02, 0x03>>)
      <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
        13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
        146, 57>>
  """
  @spec kec(binary()) :: keccak_hash
  def kec(data) do
    :keccakf1600.sha3_256(data)
  end

  @doc """
  Initializes a new Keccak mac stream.

  ## Examples

      iex> keccak_mac = ExthCrypto.Hash.Keccak.init_mac()
      iex> is_nil(keccak_mac)
      false
  """
  @spec init_mac() :: keccak_mac
  def init_mac() do
    :keccakf1600.init(:sha3_256)
  end

  @doc """
  Updates a given Keccak mac stream with the given
  secret and data, returning a new mac stream.

  ## Examples

      iex> keccak_mac = ExthCrypto.Hash.Keccak.init_mac()
      ...> |> ExthCrypto.Hash.Keccak.update_mac("data")
      iex> is_nil(keccak_mac)
      false
  """
  @spec update_mac(keccak_mac, binary()) :: keccak_mac
  def update_mac(mac, data) do
    :keccakf1600.update(mac, data)
  end

  @doc """
  Finalizes a given Keccak mac stream to produce the current hash.

  ## Examples

      iex> ExthCrypto.Hash.Keccak.init_mac()
      ...> |> ExthCrypto.Hash.Keccak.update_mac("data")
      ...> |> ExthCrypto.Hash.Keccak.final_mac()
      ...> |> ExthCrypto.Math.bin_to_hex
      "8f54f1c2d0eb5771cd5bf67a6689fcd6eed9444d91a39e5ef32a9b4ae5ca14ff"
  """
  @spec final_mac(keccak_mac) :: keccak_hash
  def final_mac(mac) do
    :keccakf1600.final(mac)
  end
end
