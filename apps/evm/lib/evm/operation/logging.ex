defmodule EVM.Operation.Logging do
  alias EVM.{Operation, Memory, SubState}

  @doc """
  Append log record with no topics.

  TODO: Implement opcode

  ## Examples

  """
  @spec log0(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log0(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with one topic.

  TODO: Implement opcode

  ## Examples

  """
  @spec log1(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log1(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with two topics.

  TODO: Implement opcode

  ## Examples


  """
  @spec log2(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log2(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with three topics.

  TODO: Implement opcode

  ## Examples


  """
  @spec log3(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log3(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with four topics.

  TODO: Implement opcode

  ## Examples

  """
  @spec log4(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log4(args, vm_map) do
    args |> log(vm_map)
  end


  @spec log(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  defp log([offset, size | topics], %{exec_env: exec_env, sub_state: sub_state, machine_state: machine_state}) do
    {data, _} = machine_state |> Memory.read(offset, size)
    address = exec_env.address
    updated_substate = sub_state |> SubState.add_log(address, topics, data)

    %{sub_state: updated_substate}
  end
end
