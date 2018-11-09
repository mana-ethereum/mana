defmodule Exth do
  @moduledoc """
  General helper functions, like for inspection.
  """
  require Logger

  @spec inspect(any(), String.t() | nil) :: any()
  def inspect(variable, prefix \\ nil) do
    args = if prefix, do: [prefix, variable], else: variable

    # credo:disable-for-next-line
    IO.inspect(args, limit: :infinity)

    variable
  end

  @spec trace((() -> String.t())) :: :ok
  def trace(fun) do
    _ = if System.get_env("TRACE"), do: Logger.debug(fun)

    :ok
  end
end
