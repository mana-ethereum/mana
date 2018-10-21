defmodule EVM.MessageCallTest do
  use ExUnit.Case, async: true
  doctest EVM.MessageCall

  alias EVM.AccountRepo
  alias EVM.MessageCall
  alias EVM.Mock.MockAccountRepo

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
        execution_value: 100,
        output_params: {0, 256}
      )

    %{machine_state: machine_state, exec_env: _exec_env, sub_state: _sub_state} =
      MessageCall.call(message_call)

    # Code was to add 1 + 3 = 4 and store in memory.
    assert machine_state.memory == <<0x4::256>>
    assert machine_state.gas == message_call.execution_value - 24
    assert machine_state.active_words == 8
    assert has_success_on_stack?(machine_state.stack)
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
    assert has_failure_on_stack?(machine_state.stack)
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
    assert has_failure_on_stack?(machine_state.stack)
  end

  test "sets last last_return_data to empty binary on failure" do
    pre_machine_state = build(:machine_state, last_return_data: <<1, 2, 3, 4, 5>>)

    message_call =
      build(:message_call,
        current_machine_state: pre_machine_state,
        value: 9000,
        execution_value: 100
      )

    %{machine_state: machine_state} = MessageCall.call(message_call)

    assert has_failure_on_stack?(machine_state.stack)
    assert machine_state.last_return_data == <<>>
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

  test "truncates message call's output if output's byte size is bigger than output_params" do
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
        execution_value: 100,
        output_params: {0, 2}
      )

    %{machine_state: machine_state, exec_env: _exec_env, sub_state: _sub_state} =
      MessageCall.call(message_call)

    assert machine_state.memory == <<0, 0>>
    assert machine_state.active_words == 1
  end

  describe "when recipient address is precompiled contract 3" do
    test "fails if it runs out of gas" do
      pre_machine_state = build(:machine_state)
      precompiled_contract = EVM.Builtin.Rip160.contract_address()

      message_call =
        build(:message_call,
          current_machine_state: pre_machine_state,
          value: 0,
          code_owner: precompiled_contract,
          recipient: precompiled_contract
        )

      assert %{machine_state: machine_state} = MessageCall.call(message_call)
      assert machine_state.gas == 0
      assert has_failure_on_stack?(machine_state.stack)
    end

    test "includes the address in the substate's touched accounts" do
      pre_machine_state = build(:machine_state)
      precompiled_contract = EVM.Builtin.Rip160.contract_address()

      message_call =
        build(:message_call,
          current_machine_state: pre_machine_state,
          value: 0,
          code_owner: precompiled_contract,
          recipient: precompiled_contract
        )

      assert %{sub_state: sub_state} = MessageCall.call(message_call)
      assert Enum.member?(sub_state.touched_accounts, precompiled_contract)
    end
  end

  defp has_failure_on_stack?(stack) do
    {value, _rest} = EVM.Stack.pop(stack)
    value == 0
  end

  defp has_success_on_stack?(stack) do
    {value, _rest} = EVM.Stack.pop(stack)
    value == 1
  end
end
