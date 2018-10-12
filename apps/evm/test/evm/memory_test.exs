defmodule EVM.MemoryTest do
  alias EVM.{MachineState, Memory}
  use ExUnit.Case, async: true
  doctest EVM.Memory

  describe "write/4" do
    test "returns the machine_state unchanged if data size is zero" do
      machine_state = %MachineState{}
      updated_machine_state = Memory.write(machine_state, 256, <<>>, 0)
      assert machine_state == updated_machine_state
    end

    test "truncates input if the size parameter is smaller than input's size" do
      machine_state = %MachineState{}
      input = Enum.reduce(1..60, <<>>, fn i, acc -> <<i>> <> acc end)

      updated_machine_state = Memory.write(machine_state, 0, input, 2)

      assert updated_machine_state.memory == <<60, 59>>
      assert updated_machine_state.active_words == 1
    end

    test "does not truncate input if the size parameter is bigger than input's size" do
      machine_state = %MachineState{}
      input = Enum.reduce(1..60, <<>>, fn i, acc -> <<i>> <> acc end)

      updated_machine_state = Memory.write(machine_state, 0, input, 61)

      assert updated_machine_state.memory == input
      assert updated_machine_state.active_words == 2
    end
  end
end
