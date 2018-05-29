defmodule Blockchain.Test do
  @moduledoc """
  Helper functions related to testing the Blockchain.

  NOTE: Remember to recompile test after updading chain configs.
  """

  @chain Blockchain.Chain.load_chain(:ropsten)

  @doc """
  Returns a test chain similar to Ropsten.
  """
  def ropsten_chain(), do: @chain
end
