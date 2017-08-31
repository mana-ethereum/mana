defmodule EVM.Operation.Metadata do
  @moduledoc """
  A simple struct to store metadata about all VM instructions.
  """

  defstruct [
    id: nil,
    sym: nil,
    fun: nil,
    args: [],
    d: nil,
    a: nil,
    description: nil
  ]

  @type t :: %__MODULE__{
    id: integer(),
    sym: atom(),
    fun: atom(),
    args: [],
    d: integer(),
    a: integer(),
    description: String.t
  }
end
