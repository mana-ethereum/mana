defmodule EVM.Debugger.BreakpointTest do
  use ExUnit.Case, async: true
  doctest EVM.Debugger.Breakpoint
  alias EVM.Debugger.Breakpoint

  setup_all do
    Breakpoint.init()

    :ok
  end
end
