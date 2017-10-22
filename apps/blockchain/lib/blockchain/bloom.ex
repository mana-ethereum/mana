defmodule Blockchain.Bloom do
  @required_bytes [0, 2, 4]

  @spec create(binary()) :: [integer()]
  def create(data) when is_binary(data) do
    data
    |> sha3_bytes
    |> Enum.reduce(new_bloom_list(), fn(byte, acc) ->
      acc |> List.replace_at(byte, 1)
    end)
  end

  @spec new_bloom_list() :: [integer()]
  defp new_bloom_list do
    List.duplicate(0, 256)
  end

  @spec sha3_bytes(binary()) :: [integer]
  def sha3_bytes(data) when is_binary(data) do
    data
    |> sha3_binary
    |> to_bytes
    |> required_bytes
  end

  @spec to_bytes(binary(), [] | [integer]) :: [integer()]
  defp to_bytes(binary, acc \\ [])

  defp to_bytes("", acc), do: acc

  defp to_bytes(<<b :: size(8), tail :: bitstring>>, acc), do: to_bytes(tail, acc ++ [b])

  @spec sha3_binary(binary()) :: binary()
  defp sha3_binary(data) when is_binary(data), do: data |> :keccakf1600.sha3_256

  @spec required_bytes([integer()]) :: [integer]
  defp required_bytes(bytes) when is_list(bytes) do
    @required_bytes
    |> Enum.map(fn(byte) ->
      bytes |> Enum.at(byte)
    end)
  end
end
