defmodule ExWire.Kademlia.XorDistance do
  @moduledoc """
  XOR metric used in Kademlia.
  """
  use Bitwise

  @doc """
  Calculates XOR metric value between two binaries.

  ## Examples

      iex> {:ok, id1} = "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d" |> Base.decode16(case: :lower)
      iex> {:ok, id2} = "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606" |> Base.decode16(case: :lower)
      iex> ExWire.Kademlia.XorDistance.distance(id1, id2)
      250
      iex> ExWire.Kademlia.XorDistance.distance(id1, id1)
      0
  """

  @spec distance(binary(), binary()) :: integer()
  def distance(id1, id2) do
    id1_integer = id1 |> :binary.decode_unsigned()
    id2_integer = id2 |> :binary.decode_unsigned()
    xor_result = id1_integer ^^^ id2_integer

    xor_result
    |> :binary.encode_unsigned()
    |> binary_to_bits()
    |> Enum.sum()
  end

  @doc """
  Calculates common bit prefix between two binaries.

    ## Examples

        iex> {:ok, id1} = "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d" |> Base.decode16(case: :lower)
        iex> {:ok, id2} = "30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606" |> Base.decode16(case: :lower)
        iex> ExWire.Kademlia.XorDistance.common_prefix(id1, id2)
        1
        iex> ExWire.Kademlia.XorDistance.common_prefix(id1, id1)
        512
  """
  @spec common_prefix(binary(), binary()) :: integer()
  def common_prefix(id1, id2) do
    prefix(id1, id2)
  end

  @spec binary_to_bits(binary) :: [integer()]
  defp binary_to_bits(binary) do
    for(<<bit::1 <- binary>>, do: bit)
  end

  @spec prefix(binary(), binary(), integer()) :: integer()
  defp prefix(bin1, bin2, acc \\ 0)

  defp prefix(<<1::1, tail1::bitstring>>, <<1::1, tail2::bitstring>>, acc),
    do: prefix(tail1, tail2, acc + 1)

  defp prefix(<<0::1, tail1::bitstring>>, <<0::1, tail2::bitstring>>, acc),
    do: prefix(tail1, tail2, acc + 1)

  defp prefix(_bin1, _bin2, acc), do: acc
end
