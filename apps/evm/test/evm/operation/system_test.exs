defmodule EVM.Operation.SystemTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.System

  alias EVM.{ExecEnv, Stack, Address, Operation, MachineState, SubState, MachineCode, VM}
  alias EVM.Interface.AccountInterface
  alias EVM.Interface.Mock.{MockAccountInterface, MockBlockInterface}

  describe "selfdestruct/2" do
    test "transfers wei to refund account" do
      selfdestruct_address = 0x0000000000000000000000000000000000000001
      refund_address = 0x0000000000000000000000000000000000000002
      account_map = %{selfdestruct_address => %{balance: 5_000, nonce: 5}}
      account_interface = MockAccountInterface.new(account_map)
      exec_env = %ExecEnv{address: selfdestruct_address, account_interface: account_interface}
      vm_opts = %{stack: [], exec_env: exec_env, sub_state: SubState.empty()}
      new_exec_env = Operation.System.selfdestruct([refund_address], vm_opts)[:exec_env]
      accounts = new_exec_env.account_interface.account_map

      expected_refund_account = %{balance: 5000, code: <<>>, nonce: 0, storage: %{}}
      assert Map.get(accounts, Address.new(refund_address)) == expected_refund_account
      assert Map.get(accounts, selfdestruct_address) == nil
    end
  end

  # https://github.com/poanetwork/mana/issues/190
  # describe "revert" do
  #   test "halts execution reverting state changes but returning data and remaining gas" do
  #     account =
  #       MockAccountInterface.new(
  #         %{
  #           1 => %{
  #             balance: 0,
  #             code: <<>>,
  #             nonce: 0,
  #             storage: %{}
  #           }
  #         },
  #         %{
  #           gas: 0,
  #           sub_state: %EVM.SubState{},
  #           output: <<>>
  #         }
  #       )

  #     machine_code =
  #       MachineCode.compile([
  #         :push1,
  #         1,
  #         :push1,
  #         1,
  #         :push1,
  #         2,
  #         :push1,
  #         10,
  #         :sstore,
  #         :revert,
  #         :push1,
  #         10,
  #         :pop
  #       ])

  #     exec_env = %ExecEnv{account_interface: account, address: 1, machine_code: machine_code}
  #     machine_state = %MachineState{program_counter: 0, gas: 100_000, stack: []}
  #     substate = %SubState{}

  #     {updated_machine_state, _, updated_exec_env, output} =
  #       VM.exec(machine_state, substate, exec_env)

  #     assert updated_machine_state.gas == 79985

  #     assert updated_exec_env.account_interface.account_map == %{
  #              1 => %{balance: 0, code: "", nonce: 0, storage: %{}}
  #            }

  #     assert output == <<0>>
  #   end
  # end

  describe "return" do
    test "halts execution returning output data" do
      account =
        MockAccountInterface.new(
          %{
            1 => %{
              balance: 0,
              code: <<>>,
              nonce: 0,
              storage: %{}
            }
          },
          %{
            gas: 0,
            sub_state: %EVM.SubState{},
            output: <<>>
          }
        )

      machine_code =
        MachineCode.compile([
          :push1,
          1,
          :push1,
          1,
          :push1,
          2,
          :push1,
          10,
          :sstore,
          :return,
          :push1,
          10,
          :pop
        ])

      exec_env = %ExecEnv{account_interface: account, address: 1, machine_code: machine_code}
      machine_state = %MachineState{program_counter: 0, gas: 100_000, stack: []}
      substate = %SubState{}

      {updated_machine_state, _, updated_exec_env, output} =
        VM.exec(machine_state, substate, exec_env)

      assert updated_machine_state.gas == 79985

      assert updated_exec_env.account_interface.account_map == %{
               1 => %{balance: 0, code: "", nonce: 0, storage: %{10 => 2}}
             }

      assert output == <<0>>
    end
  end

  describe "create/2" do
    test "creates a new account with associated code" do
      block_interface = MockBlockInterface.new(%Block.Header{})
      account_map = %{<<100::160>> => %{balance: 5_000, nonce: 5}}
      contract_result = %{gas: 500, sub_state: nil, output: "output"}
      account_interface = MockAccountInterface.new(account_map, contract_result)

      exec_env = %ExecEnv{
        stack_depth: 0,
        address: <<100::160>>,
        account_interface: account_interface,
        block_interface: block_interface
      }

      machine_state = %MachineState{
        gas: 300,
        stack: [1],
        memory: "________" <> "input"
      }

      %{machine_state: n_machine_state} =
        Operation.System.create([1_000, 5, 5], %{exec_env: exec_env, machine_state: machine_state})

      expected_machine_state = %MachineState{
        gas: 500,
        stack: [0x601BCC2189B7096D8DFAA6F74EFEEBEF20486D0D, 1],
        active_words: 1,
        memory: "________input"
      }

      assert n_machine_state == expected_machine_state
    end
  end

  describe "call/2" do
    test "failes to Transfer wei from callers account to callees account" do
      account_map = %{
        <<0::160>> => %{balance: 100, nonce: 5, code: <<>>},
        <<1::160>> => %{balance: 100, nonce: 5, code: <<>>},
        <<2::160>> => %{balance: 100, nonce: 5, code: <<>>}
      }

      account_interface = MockAccountInterface.new(account_map)

      exec_env = %ExecEnv{
        account_interface: account_interface,
        sender: <<0::160>>,
        address: <<0::160>>
      }

      machine_state = %MachineState{gas: 1_000_000}

      %{machine_state: machine_state} =
        Operation.System.call([10, 1, 1, 0, 0, 0, 0], %{
          exec_env: exec_env,
          machine_state: machine_state
        })

      assert Stack.peek(machine_state.stack) == 0
      assert AccountInterface.get_account_balance(exec_env.account_interface, <<0::160>>) == 100
      assert AccountInterface.get_account_balance(exec_env.account_interface, <<1::160>>) == 100
    end
  end
end
