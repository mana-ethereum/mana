defmodule EVM.Debugger.BreakpointTest do
  use ExUnit.Case, async: true
  doctest EVM.Debugger.Breakpoint

  setup_all do
    EVM.Debugger.Breakpoint.init()

    :ok
  end

end