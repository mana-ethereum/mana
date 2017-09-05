defmodule EVM.Operation.EnvironmentalInformation do
  alias EVM.Operation
  alias EVM.Helpers
  alias EVM.Interface.AccountInterface

  @doc """
  Get address of currently executing account.

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.address([], %{exec_env: %EVM.ExecEnv{address: <<01, 00>>}})
      <<1, 0>>
  """
  @spec address(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def address([], %{exec_env: exec_env}) do
    exec_env.address
  end

  @doc """
  Get balance of the given account.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: 500)
      iex> exec_env = %EVM.ExecEnv{account_interface: account_interface}
      iex> EVM.Operation.EnvironmentalInformation.balance([123], %{state: state, exec_env: exec_env})
      500

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: nil)
      iex> exec_env = %EVM.ExecEnv{account_interface: account_interface}
      iex> EVM.Operation.EnvironmentalInformation.balance([123], %{state: state, exec_env: exec_env})
      0
  """
  @spec balance(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def balance([address], %{state: state, exec_env: exec_env}) do
    wrapped_address = Helpers.wrap_address(address)

    case AccountInterface.get_account_balance(exec_env.account_interface, state, wrapped_address) do
      nil -> 0
      balance -> balance
    end
  end

  @doc """
  Get execution origination address.

  This is the sender of original transaction; it is never an account with non-empty associated code.

  ## Examples

      iex> exec_env = %EVM.ExecEnv{originator: <<1::160>>, sender: <<2::160>>}
      iex> EVM.Operation.EnvironmentalInformation.origin([], %{exec_env: exec_env})
      <<1::160>>
  """
  @spec origin(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def origin([], %{exec_env: exec_env}) do
    exec_env.originator
  end

  @doc """
  Get caller address.

  This is the address of the account that is directly responsible for this execution.

  ## Examples

      iex> exec_env = %EVM.ExecEnv{originator: <<1::160>>, sender: <<2::160>>}
      iex> EVM.Operation.EnvironmentalInformation.caller([], %{exec_env: exec_env})
      <<2::160>>
  """
  @spec caller(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def caller([], %{exec_env: exec_env}) do
    exec_env.sender
  end

  @doc """
  Get deposited value by the instruction / transaction responsible for this execution.

  ## Examples

      iex> exec_env = %EVM.ExecEnv{value_in_wei: 1_000}
      iex> EVM.Operation.EnvironmentalInformation.callvalue([], %{exec_env: exec_env})
      1_000
  """
  @spec callvalue(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def callvalue([], %{exec_env: exec_env}) do
    exec_env.value_in_wei
  end

  @doc """
  Get input data of current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.calldataload([0], %{exec_env: %{data: (for n <- 1..50, into: <<>>, do: <<255>>)}})
      -1

      iex> EVM.Operation.EnvironmentalInformation.calldataload([0], %{exec_env: %{data: (for n <- 1..3, into: <<>>, do: <<1>>)}})
      <<1::8, 1::8, 1::8, 0::232>> |> EVM.Helpers.decode_signed

      iex> EVM.Operation.EnvironmentalInformation.calldataload([100], %{exec_env: %{data: (for n <- 1..3, into: <<>>, do: <<1>>)}})
      0
  """
  @spec calldataload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldataload([s0], %{exec_env: %{data: data}}) do
    Helpers.read_zero_padded(data, s0, 32) |> Helpers.decode_signed
  end

  @doc """
  Get size of input data in current environment.

  ## Examples

      iex> exec_env = %EVM.ExecEnv{data: "hello world"}
      iex> EVM.Operation.EnvironmentalInformation.calldatasize([], %{exec_env: exec_env})
      11
  """
  @spec calldatasize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldatasize([], %{exec_env: exec_env}) do
    exec_env.data |> byte_size
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
