defmodule Blockchain.Test do
  @moduledoc """
  Helper functions related to testing the Blockchain.

  NOTE: Remember to recompile test after updating chain configs.
  """

  @chain Blockchain.Chain.load_chain(:ropsten)
  @frontier_chain Blockchain.Chain.load_chain(:frontier_test, EVM.Configuration.Frontier.new())

  @doc """
  Returns a test chain similar to Ropsten.
  """
  def ropsten_chain(), do: @chain
  def frontier_chain(), do: @frontier_chain
end
