defmodule ExCrypto.Keccak do
  @moduledoc """
  Simple wrapper for Keccak function for Ethereum.

  Note: This module defines KECCAK as defined by Ethereum, which differs slightly
  than that assigned as the new SHA-3 variant. For SHA-3, a few constants have
  been changed prior to adoption by NIST, but after adoption by Ethereum.
  """

  @type keccak_hash :: ExCrypto.hash

  @doc """
  Returns the keccak sha256 of a given input.

  ## Examples

      iex> ExCrypto.Keccak.kec("hello world")
      <<71, 23, 50, 133, 168, 215, 52, 30, 94, 151, 47, 198, 119, 40, 99,
        132, 248, 2, 248, 239, 66, 165, 236, 95, 3, 187, 250, 37, 76, 176,
        31, 173>>

      iex> ExCrypto.Keccak.kec(<<0x01, 0x02, 0x03>>)
      <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
        13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
        146, 57>>
  """
  @spec kec(binary()) :: keccak_hash
  def kec(data) do
    :keccakf1600.sha3_256(data)
  end
end