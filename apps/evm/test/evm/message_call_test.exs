defmodule EVM.MessageCallTest do
  use ExUnit.Case, async: true
  doctest EVM.MessageCall

  alias EVM.MessageCall
  alias EVM.Mock.MockAccountRepo
  alias EVM.AccountRepo

  import EVM.TestFactory, only: [build: 1, build: 2]

  test "returns machine state, exec_env, and sub_state upon success" do
    message_call = build(:message_call)

    result = MessageCall.call(message_call)

    assert %{machine_state: _ms, exec_env: _env, sub_state: _sstate} = result
  end

  test "updates machine state based on code executed" do
    code = build(:machine_code, operations: [:push1, 1, :push1, 3, :add, :push1, 0x00, :mstore])

    recipient = %{address: <<0x9::160>>, code: code}

    account_repo =
      build(:mock_account_repo)
      |> MockAccountRepo.add_account(recipient.address, %{balance: 10, code: recipient.code})

    pre_exec_env =
      build(:exec_env,
        account_repo: account_repo
      )

    pre_machine_state = build(:machine_state)

    message_call =
      build(:message_call,
        current_exec_env: pre_exec_env,
        current_machine_state: pre_machine_state,
        recipient: recipient.address,
        code_owner: recipient.address,
        execution_value: 100
      )

    %{machine_state: machine_state, exec_env: _exec_env, sub_state: _sub_state} =
      MessageCall.call(message_call)

    # Code was to add 1 + 3 = 4 and store in memory.
    assert machine_state.memory == <<0x4::256>>
    assert machine_state.gas == message_call.execution_value - 24
    assert machine_state.active_words == pre_machine_state.active_words + 1
    assert machine_state.stack == pre_machine_state.stack ++ [1]
  end

  test "transfers value from current account to recipient" do
    current_account = %{address: <<0x80::160>>, balance: 100}
    recipient_account = %{address: <<0x90::160>>, balance: 0}

    account_repo =
      build(:mock_account_repo,
        account_map: %{
          current_account.address => %{balance: current_account.balance},
          recipient_account.address => %{balance: recipient_account.balance}
        }
      )

    pre_exec_env =
      build(:exec_env,
        address: current_account.address,
        account_repo: account_repo
      )

    message_call =
      build(:message_call,
        recipient: recipient_account.address,
        value: 40,
        current_exec_env: pre_exec_env
      )

    %{exec_env: exec_env} = MessageCall.call(message_call)
    account_repo = exec_env.account_repo

    assert AccountRepo.repo(account_repo).get_account_balance(
             account_repo,
             recipient_account.address
           ) == recipient_account.balance + message_call.value

    assert AccountRepo.repo(account_repo).get_account_balance(
             account_repo,
             current_account.address
           ) == current_account.balance - message_call.value
  end

  test "fails if stack is too deep, only returning the machine state" do
    pre_machine_state = build(:machine_state)

    message_call =
      build(:message_call,
        current_machine_state: pre_machine_state,
        stack_depth: EVM.Functions.max_stack_depth() + 1
      )

    assert %{machine_state: machine_state} = MessageCall.call(message_call)
    assert machine_state.gas == pre_machine_state.gas + message_call.execution_value
    assert machine_state.stack == pre_machine_state.stack ++ [0]
  end

  test "fails if there aren't enough funds to perform call" do
    pre_machine_state = build(:machine_state)

    message_call =
      build(:message_call,
        current_machine_state: pre_machine_state,
        value: 9000,
        execution_value: 100
      )

    assert %{machine_state: machine_state} = MessageCall.call(message_call)
    assert machine_state.gas == pre_machine_state.gas + message_call.execution_value
    assert machine_state.stack == pre_machine_state.stack ++ [0]
  end

  test "sets machine_state.active_words" do
    pre_machine_state = build(:machine_state)

    message_call =
      build(:message_call,
        current_machine_state: pre_machine_state,
        output_params: {256, 32}
      )

    %{machine_state: %{active_words: active_words}} = MessageCall.call(message_call)

    assert active_words == 9
  end

  test "doesn't set machine_state.active_words if out_size is zero" do
    pre_machine_state = build(:machine_state)

    message_call =
      build(:message_call,
        current_machine_state: pre_machine_state,
        output_params: {256, 0}
      )

    %{machine_state: %{active_words: active_words}} = MessageCall.call(message_call)

    assert active_words == 0
  end
end
