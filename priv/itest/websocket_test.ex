defmodule WebsocketTest do
  @moduledoc """
  Expose at least two functions.
  1. Flags -> flags with which you would like to kick off the release
  2. A list of tests you want to perform on the running release.
  """
  def tests() do
    [&flags/0, [&invoke_test/0]]
  end

  defp flags(), do: ['run']

  defp invoke_test() do
    IO.puts("Invoked test!")
  end
end
