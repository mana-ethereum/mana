defmodule BitHelper do
  @moduledoc """
  Helpers for common operations on the blockchain.
  """

  use Bitwise

  @type keccak_hash :: binary()

  @doc """
  Simply returns the rightmost n bits of a binary.

  ## Examples

      iex> BitHelper.mask(0b111101111, 6)
      0b101111

      iex> BitHelper.mask(0b101101, 3)
      0b101

      iex> BitHelper.mask(0b011, 1)
      1

      iex> BitHelper.mask(0b011, 0)
      0

      iex> BitHelper.mask(0b010, 1)
      0

      iex> BitHelper.mask(0b010, 20)
      0b010
  """
  @spec mask(integer(), integer()) :: integer()
  def mask(n, bits) when is_integer(n) do
    # Calculates n bitwise-and 0b1111...<bits>
    n &&& ( ( 2 <<< ( bits - 1 ) ) - 1 )
  end

  @doc """
  Simply returns the rightmost n bits of a binary.

  ## Examples

      iex> BitHelper.mask_bitstring(<<0b111101111>>, 6)
      <<0b101111::size(6)>>

      iex> BitHelper.mask_bitstring(<<0b101101>>, 3)
      <<0b101::size(3)>>

      iex> BitHelper.mask_bitstring(<<0b011>>, 1)
      <<1::size(1)>>

      iex> BitHelper.mask_bitstring(<<0b011>>, 0)
      <<>>

      iex> BitHelper.mask_bitstring(<<0b010>>, 1)
      <<0::size(1)>>

      iex> BitHelper.mask_bitstring(<<0b010>>, 20)
      <<0, 0, 2::size(4)>>

      iex> BitHelper.mask_bitstring(<<0b010>>, 3)
      <<0b010::size(3)>>

      iex> BitHelper.mask_bitstring(<<>>, 3)
      <<0b000::size(3)>>
  """
  @spec mask_bitstring(bitstring(), integer()) :: bitstring()
  def mask_bitstring(b, bits) do
    size = bit_size(b)
    skip_size = max(size - bits, 0)
    padding = max(bits  - size, 0)

    <<_::size(skip_size), included_part::bits>> = b

    <<0::size(padding), included_part::bitstring>>
  end

  @doc """
  Returns the keccak sha256 of a given input.

  ## Examples

      iex> BitHelper.kec("hello world")
      <<71, 23, 50, 133, 168, 215, 52, 30, 94, 151, 47, 198, 119, 40, 99,
             132, 248, 2, 248, 239, 66, 165, 236, 95, 3, 187, 250, 37, 76, 176,
             31, 173>>

      iex> BitHelper.kec(<<0x01, 0x02, 0x03>>)
      <<241, 136, 94, 218, 84, 183, 160, 83, 49, 140, 212, 30, 32, 147, 34,
             13, 171, 21, 214, 83, 129, 177, 21, 122, 54, 51, 168, 59, 253, 92,
             146, 57>>
  """
  @spec kec(binary()) :: keccak_hash
  def kec(data) do
    :keccakf1600.sha3_256(data)
  end
end