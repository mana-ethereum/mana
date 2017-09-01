defmodule EVM.Interface.Mock.MockBlockInterface do
  @moduledoc """
  Simple implementation of a block interface that allows
  us to specify the given block headers.
  """

  defstruct [
    block_header: nil,
    block_map: %{}
  ]

  @spec new(Block.Header.t, %{EVM.hash => Block.Header.t}) :: EVM.Interface.BlockInterface.t
  def new(block_header, block_map \\ %{}) do
    %__MODULE__{
      block_header: block_header,
      block_map: block_map
    }
  end
end

defimpl EVM.Interface.BlockInterface, for: EVM.Interface.Mock.MockBlockInterface do

  @spec get_block_header(EVM.Interface.BlockInterface.t) :: Block.Header.t
  def get_block_header(mock_block_interface) do
    mock_block_interface.block_header
  end

  @spec get_block_by_hash(EVM.Interface.BlockInterface.t, EVM.hash) :: Block.Header.t
  def get_block_by_hash(mock_block_interface, block_hash) do
    mock_block_interface.block_map[block_hash]
  end

end