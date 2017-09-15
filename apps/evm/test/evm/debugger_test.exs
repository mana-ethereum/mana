defmodule EVM.DebuggerTest do
  use ExUnit.Case, async: true
  doctest EVM.Debugger

  setup_all do
    EVM.Debugger.Breakpoint.init()

    :ok
  end

end