defmodule JSONRPC2.Struct.EthSyncing do
  defstruct [
    :currentBlock,
    :startingBlock,
    :highestBlock
  ]

  @type output :: %__MODULE__{
          currentBlock: String.t(),
          startingBlock: String.t(),
          highestBlock: String.t()
        }

  @type input :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}

  @spec output(input()) :: output
  def output({current_block, starting_block, highest_block}) do
    %__MODULE__{
      currentBlock: to_hex(current_block),
      startingBlock: to_hex(starting_block),
      highestBlock: to_hex(highest_block)
    }
  end

  @spec to_hex(non_neg_integer()) :: String.t()
  defp to_hex(0), do: "0x0"

  defp to_hex(n),
    do: "0x" <> (n |> :binary.encode_unsigned() |> Base.encode16() |> String.trim_leading("0"))
end
