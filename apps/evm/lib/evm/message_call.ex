defmodule EVM.MessageCall do
  alias EVM.{ExecEnv, Memory, Builtin, VM, Functions, Stack, MachineState, SubState}
  alias EVM.Interface.AccountInterface

  @moduledoc """
  Describes a message call function that used for all call operations (call, delegatecall, callcode, staticcall).
  """
  defstruct [
    :current_exec_env,
    :current_machine_state,
    :current_sub_state,
    :output_params,
    :sender,
    :originator,
    :recipient,
    :code_owner,
    :gas_price,
    :value,
    :execution_value,
    :data,
    :stack_depth
  ]

  @type out_size :: integer()
  @type out_offset :: integer()
  @type output_params :: {out_offset(), out_size()}

  @typedoc """
  Terms from the Yellow Paper:

  s: sender,
  o: originator,
  r: recipient,
  c: code_owner,
  p: gas_price,
  v: value,
  v with overline: execution_value,
  d: data,
  e: stack_depth
  """
  @type t :: %__MODULE__{
          current_exec_env: ExecEnv.t(),
          current_machine_state: MachineState.t(),
          current_sub_state: SubState.t(),
          output_params: output_params(),
          sender: EVM.Address.t(),
          originator: EVM.Address.t(),
          recipient: EVM.Address.t(),
          code_owner: EVM.Address.t(),
          gas_price: EVM.Gas.gas_price(),
          value: integer(),
          execution_value: integer(),
          data: binary(),
          stack_depth: integer()
        }

  @doc """
  Message call function. Described as Θ in the Eq.(98) of the Yellow Paper
  """
  @spec call(t) ::
          %{machine_state: MachineState.t(), exec_env: ExecEnv.t(), sub_state: SubState.t()}
          | %{machine_state: MachineState.t()}
  def call(message_call) do
    {out_offset, out_size} = message_call.output_params

    words = Memory.get_active_words(out_offset + out_size)

    updated_machine_state =
      MachineState.maybe_set_active_words(message_call.current_machine_state, words)

    message_call = %{message_call | current_machine_state: updated_machine_state}

    if valid_stack_depth?(message_call) && sufficient_funds?(message_call) do
      execute(message_call)
    else
      failed_call(message_call, message_call.execution_value)
    end
  end

  defp sufficient_funds?(message_call) do
    sender_balance =
      AccountInterface.get_account_balance(
        message_call.current_exec_env.account_interface,
        message_call.sender
      )

    sender_balance >= message_call.value
  end

  defp valid_stack_depth?(message_call) do
    message_call.stack_depth < Functions.max_stack_depth()
  end

  defp execute(message_call) do
    message_call = transfer_funds_if_needed(message_call)

    message_call
    |> prepare_call_execution_env()
    |> execute_call(message_call)
    |> update_state(message_call)
  end

  defp transfer_funds_if_needed(message_call) do
    if recipient_is_current_account?(message_call) do
      message_call
    else
      transfer_value_to_recipient(message_call)
    end
  end

  defp recipient_is_current_account?(message_call) do
    message_call.current_exec_env.address == message_call.recipient
  end

  def transfer_value_to_recipient(message_call) do
    exec_env =
      ExecEnv.transfer_wei_to(
        message_call.current_exec_env,
        message_call.recipient,
        message_call.value
      )

    %{message_call | current_exec_env: exec_env}
  end

  def update_state({gas_remaining, n_sub_state, n_exec_env, output}, message_call) do
    if output == :failed do
      failed_call(message_call)
    else
      {out_offset, _out_size} = message_call.output_params

      machine_state =
        message_call.current_machine_state
        |> MachineState.push(1)
        |> MachineState.refund_gas(gas_remaining)

      machine_state =
        if output == :invalid_input do
          machine_state
        else
          Memory.write(machine_state, out_offset, output)
        end

      exec_env =
        Map.put(message_call.current_exec_env, :account_interface, n_exec_env.account_interface)

      sub_state = SubState.merge(message_call.current_sub_state, n_sub_state)

      %{
        machine_state: machine_state,
        exec_env: exec_env,
        sub_state: sub_state
      }
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
      stack_depth: message_call.stack_depth + 1,
      account_interface: message_call.current_exec_env.account_interface,
      initial_account_interface: message_call.current_exec_env.initial_account_interface,
      block_interface: message_call.current_exec_env.block_interface,
      config: message_call.current_exec_env.config,
      created_accounts: message_call.current_exec_env.created_accounts
    }
  end

  defp execute_call(call_exec_env, message_call) do
    run = get_run_function(message_call.code_owner)
    run.(message_call.execution_value, call_exec_env)
  end

  @doc """
  Returns the given function to run given a contract address.
  This covers selecting a pre-defined function if specified.
  This is defined in Eq.(119) of the Yellow Paper.

  ## Examples

      iex> EVM.MessageCall.get_run_function(<<1::160>>)
      &EVM.Builtin.run_ecrec/2

      iex> EVM.MessageCall.get_run_function(<<2::160>>)
      &EVM.Builtin.run_sha256/2

      iex> EVM.MessageCall.get_run_function(<<3::160>>)
      &EVM.Builtin.run_rip160/2

      iex> EVM.MessageCall.get_run_function(<<4::160>>)
      &EVM.Builtin.run_id/2

      iex> EVM.MessageCall.get_run_function(<<5::160>>)
      &EVM.VM.run/2

      iex> EVM.MessageCall.get_run_function(<<6::160>>)
      &EVM.VM.run/2
  """
  @spec get_run_function(EVM.address()) ::
          (EVM.Gas.t(), EVM.ExecEnv.t() ->
             {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()})
  def get_run_function(code_owner) do
    case :binary.decode_unsigned(code_owner) do
      1 -> &Builtin.run_ecrec/2
      2 -> &Builtin.run_sha256/2
      3 -> &Builtin.run_rip160/2
      4 -> &Builtin.run_id/2
      _ -> &VM.run/2
    end
  end

  defp failed_call(message_call, remaining_gas \\ 0) do
    machine_state = message_call.current_machine_state
    updated_stack = Stack.push(machine_state.stack, 0)

    updated_machine_state = %{
      machine_state
      | stack: updated_stack,
        gas: machine_state.gas + remaining_gas
    }

    %{machine_state: updated_machine_state}
  end
end
