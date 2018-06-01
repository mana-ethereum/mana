defmodule EVM.GasTest do
  use ExUnit.Case, async: true
  doctest EVM.Gas

  setup do
    account_interface = EVM.Interface.Mock.MockAccountInterface.new()

    {:ok,
     %{
       account_interface: account_interface
     }}
  end

  test "Gas cost: CALL" do
    to_address = 0x0F572E5295C57F15886F9B263E2F6D2D6C7B5EC6
    inputs = [3000, to_address, 0, 0, 32, 32, 32]
    machine_state = %EVM.MachineState{program_counter: 0, stack: inputs}
    account_interface = EVM.Interface.Mock.MockAccountInterface.new()

    exec_env = %EVM.ExecEnv{
      machine_code: EVM.MachineCode.compile([:call]),
      address: to_address,
      account_interface: account_interface
    }

    cost = EVM.Gas.cost(machine_state, exec_env)

    assert cost == 28046
  end

  test "Refund: SSTORE", %{account_interface: account_interface} do


    # EVM.Debugger.enable
    # EVM.Debugger.Breakpoint.init()
    address = 0x0000000000000000000000000000000000000001
    # id = EVM.Debugger.break_on(address: EVM.Address.new(address))

    instructions = [
      :push1,
      3,
      :push1,
      5,
      :sstore,
      :push1,
      0,
      :push1,
      5,
      :sstore,
      :stop
    ]

    IO.inspect EVM.MachineCode.compile(instructions) |> Base.encode16

    exec_env = %EVM.ExecEnv{
      machine_code: EVM.MachineCode.compile(instructions),
      address: address,
      account_interface: account_interface
    }

    result = EVM.VM.run(25012, exec_env)

    expected_account_state = %{
      address => %{
        balance: 0,
        nonce: 0,
        storage: %{}
      }
    }

    expected_account_interface =
      EVM.Interface.Mock.MockAccountInterface.new(expected_account_state)

    expected_exec_env = Map.put(exec_env, :account_interface, expected_account_interface)

    assert result ==
             {0, %EVM.SubState{logs: [], refund: 15000, suicide_list: []}, expected_exec_env, ""}
  end
end
