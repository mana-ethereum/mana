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
      <<100, 75, 204, 126, 86, 67, 115, 4, 9, 153, 170, 200, 158, 118, 34,
        243, 202, 113, 251, 161, 217, 114, 253, 148, 163, 28, 59, 251, 242,
        78, 57, 56>>

      iex> BitHelper.kec(<<0x01, 0x02, 0x03>>)
      <<253, 23, 128, 166, 252, 158, 224, 218, 178, 108, 235, 75, 57, 65,
        171, 3, 230, 108, 205, 151, 13, 29, 185, 22, 18, 198, 109, 244, 81,
        91, 10, 10>>
  """
  @spec kec(binary()) :: keccak_hash
  def kec(data) do
    :keccakf1600.sha3_256(data)
  end
end