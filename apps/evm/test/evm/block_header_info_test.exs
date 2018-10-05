defmodule EVM.BlockHeaderInfoTest do
  use ExUnit.Case, async: true
  doctest EVM.BlockHeaderInfo

  alias EVM.BlockHeaderInfo

  defmodule FakeBlockHeaderInfo do
    @behaviour EVM.BlockHeaderInfo

    defstruct unimportant: nil

    @impl true
    def get_block_header(_), do: %Block.Header{number: 1}

    @impl true
    def get_ancestor_header(_, _), do: %Block.Header{number: 3}
  end

  test "block_header/1 gets the block header of the underlying implementation" do
    interface = %FakeBlockHeaderInfo{}

    header = BlockHeaderInfo.block_header(interface)

    assert header == %Block.Header{number: 1}
  end

  test "ancestor_header/2 gets the ancestor header of the underlying implementation" do
    interface = %FakeBlockHeaderInfo{}

    header = BlockHeaderInfo.ancestor_header(interface, 100)

    assert header == %Block.Header{number: 3}
  end
end
