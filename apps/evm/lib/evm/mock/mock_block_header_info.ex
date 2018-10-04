defmodule EVM.Mock.MockBlockHeaderInfo do
  @moduledoc """
  Simple implementation of current block info that allows us to specify the
  given block headers.
  """

  @behaviour EVM.BlockHeaderInfo

  alias EVM.BlockHeaderInfo

  defstruct block_header: nil, block_map: %{}

  @type block_map :: %{EVM.hash() => Block.Header.t()}

  @spec new(Block.Header.t(), block_map()) :: BlockHeaderInfo.t()
  def new(block_header, block_map \\ %{}) do
    %__MODULE__{
      block_header: block_header,
      block_map: block_map
    }
  end

  @impl true
  def get_block_header(mock_block_header_info) do
    mock_block_header_info.block_header
  end

  @impl true
  def get_ancestor_header(mock_block_header_info, nth_back) do
    current_number = mock_block_header_info.block_header.number
    number_to_find = current_number - nth_back

    block_header =
      mock_block_header_info
      |> get_all_block_headers()
      |> Enum.find(fn header -> header.number == number_to_find end)

    if block_header do
      block_header
    else
      nil
    end
  end

  @spec get_all_block_headers(BlockHeaderInfo.t()) :: [Block.Header.t()]
  defp get_all_block_headers(mock_block_header_info) do
    Map.values(mock_block_header_info.block_map)
  end
end
