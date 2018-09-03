defmodule EVM.Operation.EnvironmentalInformationTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.EnvironmentalInformation

  describe "codesize" do
    test "returns the vm_map unchanged if `size` is equal to `0`" do
      code = <<54>>
      mem_offset = 0
      code_offset = 0
      size = 0
      exec_env = %EVM.ExecEnv{machine_code: code}
      machine_state = %EVM.MachineState{}
      vm_map = %{exec_env: exec_env, machine_state: machine_state}

      result =
        EVM.Operation.EnvironmentalInformation.codecopy([mem_offset, code_offset, size], vm_map)

      assert result == %{machine_state: machine_state}
    end
  end

  describe "returndatacopy" do
    test "returns machine_state unchanged if size is zero" do
      code = <<0x3E>>
      mem_offset = 0
      code_offset = 0
      size = 0
      exec_env = %EVM.ExecEnv{machine_code: code}
      machine_state = %EVM.MachineState{}
      vm_map = %{exec_env: exec_env, machine_state: machine_state}

      result =
        EVM.Operation.EnvironmentalInformation.codecopy([mem_offset, code_offset, size], vm_map)

      assert result == %{machine_state: machine_state}
    end
  end
end
