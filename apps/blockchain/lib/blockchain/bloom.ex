defmodule Blockchain.Bloom do
  @moduledoc """
  When a block is generated or verified, the contract addresses and fields from the generated logs are added to a bloom filter. This is included in the block header.

  _From Yellow Paper 4.3.1. Transaction Receipt_: The transaction receipt is a tuple of four items comprising the post-transaction state, R, the cumulative gas used in the block containing the transaction receipt as of immediately after the transaction has happened, Ru, the set of logs created through execution of the transaction, Rl and the Bloom filter composed from information in those logs, Rb:
  """
  alias ExthCrypto.Hash.Keccak

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
      |> Keccak.kec()
      |> bit_numbers

    number |> add_bits(bits)
  end

  @spec add_bits(integer(), [integer()]) :: integer()
  defp add_bits(bloom_number, bits) do
    Enum.reduce(bits, bloom_number, fn bit_number, bloom ->
      bloom ||| 1 <<< bit_number
    end)
  end

  @spec bit_numbers(binary()) :: [integer()]
  defp bit_numbers(hash) do
    {result, _} =
      Enum.reduce(1..3, {[], hash}, fn _, acc ->
        {bits, <<head::integer-size(16), tail::bitstring>>} = acc
        new_bit = head &&& 2047

        {[new_bit | bits], tail}
      end)

    result
  end
end
