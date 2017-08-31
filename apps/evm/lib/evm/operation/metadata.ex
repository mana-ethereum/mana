defmodule EVM.Operation.Metadata do
  @moduledoc """
  A simple struct to store metadata about all VM instructions.
  """

  defstruct [
    id: nil,
    sym: nil,
    fun: nil,
    args: [],
    input_count: nil,
    output_count: nil,
    description: nil,
    group: :other
  ]

  @type t :: %__MODULE__{
    :id => integer(),
    :sym => atom(),
    :fun => atom(),
    :args => [],
    :input_count => integer(), # Denoted as δin the Yellow Paper
    :output_count => integer(), # Denoted as αin the Yellow Paper
    :description => String.t,
    :group => atom()
  }
end
