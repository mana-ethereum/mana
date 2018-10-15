defmodule EVM.MessageCall do
  alias EVM.{AccountRepo, ExecEnv, Memory, Builtin, VM, Functions, MachineState, SubState}

  @moduledoc """
  Describes a message call function that is used for all call operations (call, delegatecall, callcode, staticcall).
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
    :stack_depth,
    :static,
    :type
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
          stack_depth: integer(),
          static: boolean(),
          type: atom()
        }

  @doc """
  Message call function. Described as Θ in the Eq.(98) of the Yellow Paper
  """
  @spec call(t) ::
          %{machine_state: MachineState.t(), exec_env: ExecEnv.t(), sub_state: SubState.t()}
          | %{machine_state: MachineState.t()}
  def call(message_call) do
    message_call = set_active_words(message_call)

    if valid_stack_depth?(message_call) && sufficient_funds?(message_call) do
      execute(message_call)
    else
      failed_call(message_call, message_call.execution_value)
    end
  end

  defp set_active_words(message_call) do
    {out_offset, out_size} = message_call.output_params

    if out_size == 0 do
      message_call
    else
      words = Memory.get_active_words(out_offset + out_size)

      updated_machine_state =
        MachineState.maybe_set_active_words(
          message_call.current_machine_state,
          words
        )

      %{message_call | current_machine_state: updated_machine_state}
    end
  end

  defp sufficient_funds?(message_call) do
    account_repo = message_call.current_exec_env.account_repo

    sender_balance =
      AccountRepo.repo(account_repo).get_account_balance(
        account_repo,
        message_call.sender
      )

    sender_balance >= message_call.value || message_call.type == :delegate_call
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

  def update_state(
        exec_result = {_gas_remaining, _n_sub_state, _n_exec_env, output},
        message_call
      ) do
    case output do
      :failed ->
        finalize_failed_message_call(exec_result, message_call)

      {:revert, _output} ->
        finalize_reverted_message_call(exec_result, message_call)

      _ ->
        finalize_successful_message_call(exec_result, message_call)
    end
  end

  defp finalize_failed_message_call(
         {_remaining_gas, _n_sub_state, _exec_env, :failed},
         message_call
       ) do
    result = failed_call(message_call)

    if message_call_to_rip_md?(message_call) do
      sub_state =
        message_call.current_sub_state
        |> SubState.add_touched_account(message_call.recipient)

      Map.put(result, :sub_state, sub_state)
    else
      result
    end
  end

  defp message_call_to_rip_md?(message_call) do
    message_call.recipient == <<3::160>>
  end

  defp finalize_reverted_message_call(
         {gas_remaining, _n_sub_state, _ren_exec_env, {:revert, output}},
         message_call
       ) do
    {out_offset, out_size} = message_call.output_params

    machine_state =
      message_call.current_machine_state
      |> push_failure_on_stack()
      |> MachineState.refund_gas(gas_remaining)

    updated_machine_state =
      if out_size == 0 do
        %{machine_state | last_return_data: output}
      else
        machine_state = Memory.write(machine_state, out_offset, output)

        %{machine_state | last_return_data: output}
      end

    %{
      machine_state: updated_machine_state
    }
  end

  defp finalize_successful_message_call(
         {gas_remaining, n_sub_state, n_exec_env, output},
         message_call
       ) do
    {out_offset, out_size} = message_call.output_params

    machine_state =
      message_call.current_machine_state
      |> push_success_on_stack()
      |> MachineState.refund_gas(gas_remaining)

    machine_state =
      cond do
        output == :invalid_input ->
          %{machine_state | last_return_data: <<>>}

        out_size == 0 ->
          %{machine_state | last_return_data: output}

        true ->
          machine_state = Memory.write(machine_state, out_offset, output, out_size)

          %{machine_state | last_return_data: output}
      end

    exec_env = Map.put(message_call.current_exec_env, :account_repo, n_exec_env.account_repo)

    sub_state =
      message_call.current_sub_state
      |> SubState.merge(n_sub_state)
      |> SubState.add_touched_account(message_call.recipient)

    %{
      machine_state: machine_state,
      exec_env: exec_env,
      sub_state: sub_state
    }
  end

  defp prepare_call_execution_env(message_call) do
    account_repo = message_call.current_exec_env.account_repo

    machine_code =
      AccountRepo.repo(account_repo).get_account_code(
        account_repo,
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
      account_repo: message_call.current_exec_env.account_repo,
      block_header_info: message_call.current_exec_env.block_header_info,
      config: message_call.current_exec_env.config,
      static: message_call.static
    }
  end

  defp execute_call(call_exec_env, message_call) do
    run = get_run_function(message_call.code_owner, message_call.current_exec_env.config)
    run.(message_call.execution_value, call_exec_env)
  end

  @doc """
  Returns the given function to run given a contract address.
  This covers selecting a pre-defined function if specified.
  This is defined in Eq.(119) of the Yellow Paper.

  ## Examples

      iex> EVM.MessageCall.get_run_function(<<1::160>>, EVM.Configuration.Frontier.new())
      &EVM.Builtin.run_ecrec/2

      iex> EVM.MessageCall.get_run_function(<<2::160>>, EVM.Configuration.Frontier.new())
      &EVM.Builtin.run_sha256/2

      iex> EVM.MessageCall.get_run_function(<<3::160>>, EVM.Configuration.Frontier.new())
      &EVM.Builtin.run_rip160/2

      iex> EVM.MessageCall.get_run_function(<<4::160>>, EVM.Configuration.Frontier.new())
      &EVM.Builtin.run_id/2

      iex> EVM.MessageCall.get_run_function(<<5::160>>, EVM.Configuration.Frontier.new())
      &EVM.VM.run/2

      iex> EVM.MessageCall.get_run_function(<<6::160>>, EVM.Configuration.Frontier.new())
      &EVM.VM.run/2
  """
  @spec get_run_function(EVM.address(), EVM.Configuration.t()) ::
          (EVM.Gas.t(), EVM.ExecEnv.t() ->
             {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()})
  # credo:disable-for-next-line
  def get_run_function(code_owner, config) do
    address = :binary.decode_unsigned(code_owner)

    cond do
      address == 1 ->
        &Builtin.run_ecrec/2

      address == 2 ->
        &Builtin.run_sha256/2

      address == 3 ->
        &Builtin.run_rip160/2

      address == 4 ->
        &Builtin.run_id/2

      address == 5 && EVM.Configuration.for(config).has_mod_exp_builtin?(config) ->
        &Builtin.mod_exp/2

      address == 6 && EVM.Configuration.for(config).has_ec_add_builtin?(config) ->
        &Builtin.ec_add/2

      address == 7 && EVM.Configuration.for(config).has_ec_mult_builtin?(config) ->
        &Builtin.ec_mult/2

      address == 8 && EVM.Configuration.for(config).has_ec_pairing_builtin?(config) ->
        &Builtin.ec_pairing/2

      true ->
        &VM.run/2
    end
  end

  defp failed_call(message_call, remaining_gas \\ 0) do
    updated_machine_state =
      message_call.current_machine_state
      |> push_failure_on_stack()
      |> MachineState.refund_gas(remaining_gas)

    %{machine_state: updated_machine_state}
  end

  defp push_failure_on_stack(machine_state) do
    MachineState.push(machine_state, 0)
  end

  defp push_success_on_stack(machine_state) do
    MachineState.push(machine_state, 1)
  end
end
