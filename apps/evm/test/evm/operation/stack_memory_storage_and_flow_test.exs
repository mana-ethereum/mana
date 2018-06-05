defmodule EVM.Operation.StackMemoryStorageAndFlowTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.StackMemoryStorageAndFlow

  alias EVM.{MachineState, MachineCode, SubState, ExecEnv, VM}

  describe "pop/2" do
    test "pops value from stack" do
      machine_code = MachineCode.compile([:push1, 3, :push1, 5, :pop])
      exec_env = %ExecEnv{machine_code: machine_code}
      machine_state = %MachineState{program_counter: 0, gas: 24, stack: []}
      substate = %SubState{}

      {updated_machine_state, _, updated_exec_env, _} = VM.exec(machine_state, substate, exec_env)

      assert updated_machine_state.stack == [3]
    end
  end
end
