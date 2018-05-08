defmodule Blockchain.Bloom do
  use Bitwise

  @spec create(binary()) :: integer()
  def create(data) when is_binary(data) do
    bloom(0, data)
  end

  @spec add(integer(), binary()) :: integer()
  def add(bloom_number, data) when is_binary(data) do
    bloom(bloom_number, data)
  end

  @spec contains?(integer(), binary()) :: boolean()
  def contains?(current_bloom, val)
      when is_integer(current_bloom) and is_binary(val) do
    bloom = create(val)

    (bloom &&& current_bloom) == bloom
  end

  @spec bloom(integer(), binary()) :: integer()
  defp bloom(number, data) do
    bits =
      data
      |> sha3_hash
      |> bit_numbers

    number |> add_bits(bits)
  end

  @spec sha3_hash(binary()) :: binary()
  defp sha3_hash(data) do
    data |> :keccakf1600.sha3_256()
  end

  @spec add_bits(integer(), [integer()]) :: integer()
  defp add_bits(bloom_number, bits) do
    bits
    |> Enum.reduce(bloom_number, fn bit_number, bloom ->
      bloom ||| 1 <<< bit_number
    end)
  end

  @spec bit_numbers(binary()) :: [integer()]
  defp bit_numbers(hash) do
    {result, _} =
      1..3
      |> Enum.reduce({[], hash}, fn _, acc ->
        {bits, <<head::integer-size(16), tail::bitstring>>} = acc
        new_bit = head &&& 2047

        {[new_bit | bits], tail}
      end)

    result
  end
end
