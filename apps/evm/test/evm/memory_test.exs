defmodule EVM.MemoryTest do
  alias EVM.{MachineState, Memory}
  use ExUnit.Case, async: true
  doctest EVM.Memory

  test "returns the machine_state unchanged if data size is zero" do
    machine_state = %MachineState{}
    updated_machine_state = Memory.write(machine_state, 256, <<>>, 0)
    assert machine_state == updated_machine_state
  end
end
