defmodule EVM.Operation.EnvironmentalInformation do
  alias EVM.Operation
  alias EVM.Helpers

  @doc """
  Get address of currently executing account.

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.address([], %{stack: [], exec_env: %EVM.ExecEnv{address: <<01, 00>>}})
      <<1, 0>>
  """
  @spec address(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def address(_args, %{exec_env: exec_env}) do
    exec_env.address
  end

  @doc """
  Get balance of the given account.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.balance([], %{stack: []})
      :unimplemented
  """
  @spec balance(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def balance(_args, %{stack: _stack}) do
    #   # stack |> state
    #   # access state data
    :unimplemented
  end

  @doc """
  Get execution origination address.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.origin([], %{stack: []})
      :unimplemented
  """
  @spec origin(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def origin(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get caller address.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.caller([], %{stack: []})
      :unimplemented
  """
  @spec caller(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def caller(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get deposited value by the instruction/transaction responsible for this execution.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.callvalue([], %{stack: []})
      :unimplemented
  """
  @spec callvalue(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def callvalue(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get input data of current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.calldataload([0], %{exec_env: %{data: (for n <- 1..32, into: <<>>, do: <<255>>)}})
      -1
  """
  @spec calldataload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldataload([s0], %{exec_env: %{data: data}}) do
    binary_part(data, s0, 32) |> Helpers.decode_signed
  end

  @doc """
  Get size of input data in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.calldatasize([], %{stack: []})
      :unimplemented
  """
  @spec calldatasize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldatasize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy input data in current environment to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.calldatacopy([], %{stack: []})
      :unimplemented
  """
  @spec calldatacopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldatacopy(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get size of code running in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.codesize([], %{stack: []})
      :unimplemented
  """
  @spec codesize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def codesize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy code running in current environment to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.codecopy([], %{stack: []})
      :unimplemented
  """
  @spec codecopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def codecopy(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get price of gas in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.gasprice([], %{stack: []})
      :unimplemented
  """
  @spec gasprice(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def gasprice(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get size of an account’s code.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.extcodesize([], %{stack: []})
      :unimplemented
  """
  @spec extcodesize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def extcodesize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy an account’s code to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.extcodecopy([], %{stack: []})
      :unimplemented
  """
  @spec extcodecopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def extcodecopy(_args, %{stack: _stack}) do
    :unimplemented
  end
end
