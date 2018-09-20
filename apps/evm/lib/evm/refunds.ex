defmodule EVM.Refunds do
  alias EVM.{
    ExecEnv,
    MachineCode,
    MachineState,
    Operation,
    SubState,
    Configuration
  }

  @moduledoc """
  Refunds related logic.
  """

  @type t :: EVM.val()

  # Refund given (added into refund counter) when the storage value is set to zero from non-zero.
  @storage_refund 15_000
  # Refund given (added into refund counter) for destroying an account.
  @selfdestruct_refund 24_000

  @spec selfdestruct_refund() :: integer()
  def selfdestruct_refund do
    @selfdestruct_refund
  end

  @doc """
  Returns the refund amount given a cycle of the VM.

  ## Examples

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{stack: [5 , 0]}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(machine_state, sub_state, exec_env)
      15000
  """
  @spec refund(MachineState.t(), SubState.t(), ExecEnv.t()) :: t | nil
  def refund(machine_state, sub_state, exec_env) do
    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)
    refund(operation.sym, inputs, machine_state, sub_state, exec_env)
  end

  @doc """
  Returns the refund amount based on current opcode and state or nil if no refund is applicable.

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>   address: address,
      ...>   machine_code: machine_code,
      ...> }
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:selfdestruct, [], machine_state, sub_state, exec_env)
      24000

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>  account_interface: account_interface,
      ...>  machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5,4)
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.Refunds.refund(:sstore, [5, 0], machine_state, sub_state, exec_env)
      15000
  """

  # `SELFDESTRUCT` operations produce a refund if the address has not already been suicided.
  def refund(:selfdestruct, _args, _machine_state, sub_state, exec_env) do
    if exec_env.address in sub_state.selfdestruct_list do
      0
    else
      @selfdestruct_refund
    end
  end

  # `SSTORE` operations produce a refund when storage is set to zero from some non-zero value.
  def refund(:sstore, [key, new_value], _machine_state, _sub_state, exec_env) do
    if Configuration.eip1283_sstore_gas_cost_changed?(exec_env.config) do
      eip1283_sstore_refund([key, new_value], exec_env)
    else
      case ExecEnv.get_storage(exec_env, key) do
        {:ok, value} ->
          if value != 0 && new_value == 0 do
            @storage_refund
          else
            0
          end

        _ ->
          0
      end
    end
  end

  def refund(_opcode, _stack, _machine_state, _sub_state, _exec_env), do: 0

  # credo:disable-for-next-line
  defp eip1283_sstore_refund([key, new_value], exec_env) do
    initial_value = get_initial_value(exec_env, key)
    current_value = get_current_value(exec_env, key)

    cond do
      current_value == new_value ->
        0

      initial_value == current_value && initial_value == 0 ->
        0

      initial_value == current_value && initial_value != 0 && new_value == 0 ->
        15_000

      initial_value != current_value && initial_value != 0 && current_value == 0 ->
        -15_000

      initial_value != current_value && initial_value != 0 && new_value == 0 ->
        15_000

      initial_value != current_value && initial_value == new_value && initial_value == 0 ->
        19_800

      initial_value != current_value && initial_value == new_value && initial_value != 0 ->
        4_800

      true ->
        0
    end
  end

  defp get_initial_value(exec_env, key) do
    case ExecEnv.get_initial_storage(exec_env, key) do
      :account_not_found -> 0
      :key_not_found -> 0
      {:ok, value} -> value
    end
  end

  defp get_current_value(exec_env, key) do
    case ExecEnv.get_storage(exec_env, key) do
      :account_not_found -> 0
      :key_not_found -> 0
      {:ok, value} -> value
    end
  end
end
