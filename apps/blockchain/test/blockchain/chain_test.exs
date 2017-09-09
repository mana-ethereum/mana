defmodule Blockchain.ChainTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Chain
  alias Blockchain.Chain

  test "loads ropsten" do
    assert Chain.load_chain(:ropsten) == Blockchain.Test.ropsten_chain()
  end
end