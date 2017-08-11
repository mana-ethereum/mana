defmodule ExWire.Util.Timestamp do
  @moduledoc """
  Helper functions for getting current time.
  """

  @doc """
  Returns the current time as a unix epoch.
  """
  @spec now() :: integer()
  def now do
    :os.system_time(:seconds)
  end

end