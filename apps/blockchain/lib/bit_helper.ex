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

  @doc """
  Returned a binary padded to given length in bytes. Fails if
  binary is longer than desired length.

  ## Examples

      iex> BitHelper.pad(<<9>>, 5)
      <<0, 0, 0, 0, 9>>

      iex> BitHelper.pad(<<9>>, 1)
      <<9>>

      iex> BitHelper.pad(<<9, 9>>, 1)
      ** (RuntimeError) Binary too long for padding
  """
  @spec pad(binary(), integer()) :: binary()
  def pad(binary, desired_length) do
    desired_bits = desired_length * 8

    case byte_size(binary) do
      0 -> <<0::size(desired_bits)>>
      x when x <= desired_length ->
        padding_bits = ( desired_length - x ) * 8
        <<0::size(padding_bits)>> <> binary
      _ ->
        raise "Binary too long for padding"
    end
  end

  @doc """
  Similar to `:binary.encode_unsigned/1`, except we encode `0` as
  `<<>>`, the empty string. This is because the specification says that
  we cannot have any leading zeros, and so having <<0>> by itself is
  leading with a zero and prohibited.

  ## Examples

      iex> BitHelper.encode_unsigned(0)
      <<>>

      iex> BitHelper.encode_unsigned(5)
      <<5>>

      iex> BitHelper.encode_unsigned(5_000_000)
      <<76, 75, 64>>
  """
  @spec encode_unsigned(number()) :: binary()
  def encode_unsigned(0), do: <<>>
  def encode_unsigned(n), do: :binary.encode_unsigned(n)

  @doc """
  Similar to `:binary.decode_unsigned/1`, except we decode `<<>>` back to `0`,
  which is a common practice in Ethereum, since we cannot have **any** leading
  zeros.

  ## Examples

      iex> BitHelper.decode_unsigned(<<>>)
      0

      iex> BitHelper.decode_unsigned(<<5>>)
      5

      iex> BitHelper.decode_unsigned(<<76, 75, 64>>)
      5_000_000
  """
  @spec decode_unsigned(binary()) :: number()
  def decode_unsigned(<<>>), do: 0
  def decode_unsigned(bin), do: :binary.decode_unsigned(bin)

  @doc """
  Simple wrapper for decoding hex data.

  ## Examples

      iex> BitHelper.from_hex("aabbcc")
      <<0xaa, 0xbb, 0xcc>>
  """
  @spec from_hex(String.t) :: binary()
  def from_hex(hex_data), do: Base.decode16!(hex_data, case: :lower)

  @doc """
  Simple wrapper to generate hex.

  ## Examples

      iex> BitHelper.to_hex(<<0xaa, 0xbb, 0xcc>>)
      "aabbcc"
  """
  @spec to_hex(binary()) :: String.t
  def to_hex(bin), do: Base.encode16(bin, case: :lower)
end