defmodule ExWire.Util.Timestamp do
  @moduledoc """
  Helper functions for getting current time.
  """

  # seconds
  @expiration 20

  @doc """
  Returns the current time as a unix epoch.
  """
  @spec now(atom()) :: integer()
  def now(time \\ :actual)

  def now(:test) do
    1_525_704_921
  end

  def now(_) do
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
