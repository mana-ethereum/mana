defmodule Blockchain.Transaction.Receipt.Bloom do
  alias ExthCrypto.Hash.Keccak

  use Bitwise

  def empty do
    List.duplicate(0, 256)
  end

  def new(data) when is_binary(data) do
    0
    |> bloom(data)
    |> normalize()
  end

  def new(data) when is_integer(data) do
    data
    |> :binary.encode_unsigned()
    |> new()
  end

  def add(filter, data) do
    filter
    |> :binary.list_to_bin()
    |> :binary.decode_unsigned()
    |> bloom(data)
    |> normalize()
  end

  def merge(bloom1, bloom2) do
    b1 =
      bloom1
      |> to_bin()
      |> :binary.decode_unsigned()

    b2 =
      bloom2
      |> to_bin()
      |> :binary.decode_unsigned()

    normalize(b2 ||| b1)
  end

  def from_logs(logs) do
    logs
    |> Enum.reduce(empty(), fn log_entry, acc ->
      log_entry
      |> log_entry_bloom()
      |> merge(acc)
    end)
    |> :binary.list_to_bin()
  end

  def from_receipts(receipts) do
    receipts
    |> Enum.reduce(empty(), fn receipt, acc ->
      merge(receipt.bloom_filter, acc)
    end)
  end

  def log_entry_bloom(log_entry) do
    bloom = new(log_entry.address)

    Enum.reduce(log_entry.topics, bloom, fn topic, acc ->
      add(acc, topic)
    end)
  end

  defp normalize(bloom_filter) do
    bloom_filter
    |> :binary.encode_unsigned()
    |> EVM.Helpers.left_pad_bytes(256)
    |> :binary.bin_to_list()
  end

  def contains?(current_bloom, val) do
    bloom = new(val)

    merge(bloom, current_bloom) == bloom
  end

  defp bloom(number, data) do
    bits =
      data
      |> Keccak.kec()
      |> bit_numbers

    number |> add_bits(bits)
  end

  defp add_bits(bloom_number, bits) do
    Enum.reduce(bits, bloom_number, fn bit_number, bloom ->
      bloom ||| 1 <<< bit_number
    end)
  end

  defp bit_numbers(hash) do
    {result, _} =
      Enum.reduce(1..3, {[], hash}, fn _, acc ->
        {bits, <<first::integer-size(8), second::integer-size(8), tail::bitstring>>} = acc
        new_bit = (first <<< 8) + second &&& 2047

        {[new_bit | bits], tail}
      end)

    result
  end

  defp to_bin(bloom) when is_list(bloom) do
    :binary.list_to_bin(bloom)
  end

  defp to_bin(bloom) do
    bloom
  end
end
