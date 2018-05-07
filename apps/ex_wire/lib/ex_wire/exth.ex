defmodule Exth do
  @moduledoc """
  General helper functions, like for inspection.
  """

  @spec inspect(any(), String.t() | nil) :: any()
  def inspect(variable, prefix \\ nil) do
    args = if prefix, do: [prefix, variable], else: variable

    IO.inspect(args, limit: :infinity)

    variable
  end
end
