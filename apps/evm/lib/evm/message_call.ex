defmodule EVM.MessageCall do
  alias EVM.{ExecEnv, Memory, VM, Functions, Stack}
  alias EVM.Interface.AccountInterface

  @moduledoc """
  Describes a message call function that used for all call opertations (call, delegatecall, callcode, staticcall).
  """
  defstruct [
    :current_exec_env,
    :current_machine_state,
    :output_params,
    # s
    :sender,
    # o
    :originator,
    # r
    :recipient,
    # c
    :code_owner,
    # p
    :gas_price,
    # v
    :value,
    # v with overline
    :execution_value,
    # d
    :data,
    # e
    :stack_depth
  ]

  @doc """
  Message call function. Described as Θ in the Eq.(98) of the Yellow Paper
  """
  def call(message_call) do
    if valid_stack_depth?(message_call) && enough_gas?(message_call) do
      execute(message_call)
    else
      failed_call(message_call)
    end
  end

  defp enough_gas?(message_call) do
    originator_balance =
      AccountInterface.get_account_balance(
        message_call.current_exec_env.account_interface,
        message_call.originator
      )

    originator_balance >= message_call.value
  end

  defp valid_stack_depth?(message_call) do
    message_call.stack_depth < Functions.max_stack_depth()
  end

  defp execute(message_call) do
    # first transitional state
    message_call = transfer_gas_to_recipient(message_call)

    message_call
    |> prepare_call_execution_env()
    |> execute_call(message_call)
    |> update_state(message_call)
  end

  def transfer_gas_to_recipient(message_call) do
    exec_env =
      ExecEnv.transfer_wei_to(
        message_call.current_exec_env,
        message_call.recipient,
        message_call.value
      )

    %{message_call | current_exec_env: exec_env}
  end

  def update_state({n_gas, n_sub_state, n_exec_env, n_output}, message_call) do
    if n_output != :failed do
      machine_state = message_call.current_machine_state
      exec_env = message_call.current_exec_env
      {out_offset, _out_size} = message_call.output_params

      updated_stack = Stack.push(machine_state.stack, 1)
      machine_state = %{machine_state | stack: updated_stack, gas: machine_state.gas + n_gas}
      machine_state = Memory.write(machine_state, out_offset, n_output)
      exec_env = %{exec_env | account_interface: n_exec_env.account_interface}

      %{
        machine_state: machine_state,
        exec_env: exec_env,
        # https://github.com/poanetwork/mana/issues/153
        sub_state: n_sub_state
      }
    else
      failed_call(message_call)
    end
  end

  defp prepare_call_execution_env(message_call) do
    machine_code =
      AccountInterface.get_account_code(
        message_call.current_exec_env.account_interface,
        message_call.code_owner
      )

    %ExecEnv{
      address: message_call.recipient,
      originator: message_call.originator,
      gas_price: message_call.gas_price,
      data: message_call.data,
      sender: message_call.sender,
      value_in_wei: message_call.value,
      machine_code: machine_code,
      stack_depth: message_call.stack_depth,
      account_interface: message_call.current_exec_env.account_interface,
      block_interface: message_call.current_exec_env.block_interface
    }
  end

  defp execute_call(call_exec_env, message_call) do
    VM.run(message_call.execution_value, call_exec_env)
  end

  defp failed_call(message_call) do
    machine_state = message_call.current_machine_state
    updated_stack = Stack.push(machine_state.stack, 0)
    updated_machine_state = %{machine_state | stack: updated_stack}

    %{machine_state: updated_machine_state}
  end
end
