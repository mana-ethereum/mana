defmodule EVM.Operation.SystemTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.System

  alias EVM.{ExecEnv, Stack, Address, Operation, MachineState, SubState, MachineCode, VM}
  alias EVM.AccountRepo
  alias EVM.Mock.MockAccountRepo
  alias EVM.Mock.MockBlockHeaderInfo

  describe "selfdestruct/2" do
    test "transfers wei to refund account" do
      selfdestruct_address = 0x0000000000000000000000000000000000000001
      refund_address = 0x0000000000000000000000000000000000000002
      account_map = %{selfdestruct_address => %{balance: 5_000, nonce: 5}}
      account_repo = MockAccountRepo.new(account_map)
      exec_env = %ExecEnv{address: selfdestruct_address, account_repo: account_repo}
      vm_opts = %{stack: [], exec_env: exec_env, sub_state: SubState.empty()}
      new_exec_env = Operation.System.selfdestruct([refund_address], vm_opts)[:exec_env]
      accounts = new_exec_env.account_repo.account_map

      expected_refund_account = %{balance: 5000, code: <<>>, nonce: 0, storage: %{}}
      assert Map.get(accounts, Address.new(refund_address)) == expected_refund_account
      assert Map.get(accounts, selfdestruct_address) == %{balance: 0, nonce: 5}
    end
  end

  describe "revert" do
    test "halts execution reverting state changes but returning data and remaining gas" do
      account =
        MockAccountRepo.new(
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
          :revert,
          :push1,
          10,
          :pop
        ])

      exec_env = %ExecEnv{
        account_repo: account,
        address: 1,
        machine_code: machine_code,
        config: EVM.Configuration.Byzantium.new()
      }

      machine_state = %MachineState{program_counter: 0, gas: 100_000, stack: []}
      substate = %SubState{}

      {updated_machine_state, _, updated_exec_env, output} =
        VM.exec(machine_state, substate, exec_env)

      assert updated_machine_state.gas == 79_985

      assert updated_exec_env.account_repo.account_map == %{
               1 => %{balance: 0, code: "", nonce: 0, storage: %{}}
             }

      assert output == {:revert, <<0>>}
    end
  end

  describe "return" do
    test "halts execution returning output data" do
      account =
        MockAccountRepo.new(
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

      exec_env = %ExecEnv{account_repo: account, address: 1, machine_code: machine_code}
      machine_state = %MachineState{program_counter: 0, gas: 100_000, stack: []}
      substate = %SubState{}

      {updated_machine_state, _, updated_exec_env, output} =
        VM.exec(machine_state, substate, exec_env)

      assert updated_machine_state.gas == 79_985

      assert updated_exec_env.account_repo.account_map == %{
               1 => %{balance: 0, code: "", nonce: 0, storage: %{10 => 2}}
             }

      assert output == <<0>>
    end
  end

  describe "create/2" do
    test "creates a new account with associated code" do
      block_header_info = MockBlockHeaderInfo.new(%Block.Header{})
      account_map = %{<<100::160>> => %{balance: 5_000, nonce: 5}}
      contract_result = %{gas: 500, sub_state: nil, output: "output"}
      account_repo = MockAccountRepo.new(account_map, contract_result)

      exec_env = %ExecEnv{
        stack_depth: 0,
        address: <<100::160>>,
        account_repo: account_repo,
        block_header_info: block_header_info
      }

      machine_state = %MachineState{
        gas: 300,
        stack: [1],
        memory: "________" <> "input"
      }

      %{machine_state: n_machine_state} =
        Operation.System.create([1_000, 5, 5], %{
          exec_env: exec_env,
          machine_state: machine_state,
          sub_state: SubState.empty()
        })

      expected_machine_state = %MachineState{
        gas: 500,
        stack: [0x601BCC2189B7096D8DFAA6F74EFEEBEF20486D0D, 1],
        active_words: 1,
        memory: "________input",
        last_return_data: "output"
      }

      assert n_machine_state == expected_machine_state
    end

    test "merges old substate to substate after contract creation so the old logs is before the new logs" do
      new_log_entry = %EVM.LogEntry{
        address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>,
        data: <<2>>,
        topics: []
      }

      new_sub_state = %EVM.SubState{
        logs: [new_log_entry]
      }

      block_header_info = MockBlockHeaderInfo.new(%Block.Header{})
      account_map = %{<<100::160>> => %{balance: 5_000, nonce: 5}}
      contract_result = %{gas: 500, sub_state: new_sub_state, output: "output"}
      account_repo = MockAccountRepo.new(account_map, contract_result)

      exec_env = %ExecEnv{
        stack_depth: 0,
        address: <<100::160>>,
        account_repo: account_repo,
        block_header_info: block_header_info
      }

      machine_state = %MachineState{
        gas: 300,
        stack: [0xA0, 0, 1],
        memory: "________" <> "input"
      }

      old_log_entry = %EVM.LogEntry{
        address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        data: <<1>>,
        topics: [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0>>
        ]
      }

      old_sub_state = %EVM.SubState{
        logs: [old_log_entry]
      }

      %{sub_state: sub_state} =
        Operation.System.create([1_000, 5, 5], %{
          exec_env: exec_env,
          machine_state: machine_state,
          sub_state: old_sub_state
        })

      assert sub_state.logs == [old_log_entry, new_log_entry]
    end
  end

  describe "call/2" do
    test "failes to Transfer wei from callers account to callees account" do
      account_map = %{
        <<0::160>> => %{balance: 100, nonce: 5, code: <<>>},
        <<1::160>> => %{balance: 100, nonce: 5, code: <<>>},
        <<2::160>> => %{balance: 100, nonce: 5, code: <<>>}
      }

      account_repo = MockAccountRepo.new(account_map)

      exec_env = %ExecEnv{
        account_repo: account_repo,
        sender: <<0::160>>,
        address: <<0::160>>
      }

      machine_state = %MachineState{gas: 1_000_000}

      %{machine_state: machine_state} =
        Operation.System.call([10, 1, 1, 0, 0, 0, 0], %{
          exec_env: exec_env,
          machine_state: machine_state,
          sub_state: SubState.empty()
        })

      assert Stack.peek(machine_state.stack) == 0

      assert AccountRepo.repo(exec_env.account_repo).get_account_balance(
               exec_env.account_repo,
               <<0::160>>
             ) == 100

      assert AccountRepo.repo(exec_env.account_repo).get_account_balance(
               exec_env.account_repo,
               <<1::160>>
             ) == 100
    end
  end
end
