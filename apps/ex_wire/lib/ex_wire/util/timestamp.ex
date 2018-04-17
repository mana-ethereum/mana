defmodule ExWire.Util.Timestamp do
  @moduledoc """
  Helper functions for getting current time.
  """

  @expiration 20 # seconds

  @doc """
  Returns the current time as a unix epoch.
  """
  @spec now() :: integer()
  def now do
    :os.system_time(:seconds)
  end

  @doc """
  Returns the current time plus a global expiration.
  """
  @spec soon() :: integer()
  def soon do
    now() + @expiration
  end

end