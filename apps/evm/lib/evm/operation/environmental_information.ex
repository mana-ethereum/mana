defmodule EVM.Operation.EnvironmentalInformation do
  alias EVM.Operation
  alias EVM.Stack
  alias EVM.Helpers
  alias EVM.Interface.AccountInterface
  alias MerklePatriciaTree.Trie

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
      iex> account_map = %{123 => %{balance: 500}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{account_map: account_map})
      iex> exec_env = %EVM.ExecEnv{account_interface: account_interface}
      iex> EVM.Operation.EnvironmentalInformation.balance([123], %{state: state, exec_env: exec_env, machine_state: %EVM.MachineState{}}).machine_state.stack
      [500]

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> account_map = %{123 => %{balance: nil}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{account_map: account_map})
      iex> exec_env = %EVM.ExecEnv{account_interface: account_interface}
      iex> EVM.Operation.EnvironmentalInformation.balance([123], %{state: state, exec_env: exec_env, machine_state: %EVM.MachineState{}}).machine_state.stack
      [0]
  """
  @spec balance(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def balance([address], %{state: state, exec_env: exec_env, machine_state: machine_state}) do
    wrapped_address = Helpers.wrap_address(address)

    state = if Map.get(state, wrapped_address) do
      state
    else
      Map.merge(state, %{wrapped_address => %{storage: %Trie{}}})
    end

    balance = case AccountInterface.get_account_balance(exec_env.account_interface, state, wrapped_address) do
      nil -> 0
      balance -> balance
    end
    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, balance)}

    %{
      machine_state: machine_state,
      state: state,
    }
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
      iex> EVM.Operation.EnvironmentalInformation.caller([], %{exec_env: exec_env, machine_state: %EVM.MachineState{}})
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

      iex> EVM.Operation.EnvironmentalInformation.calldataload([0], %{exec_env: %{data: (for _ <- 1..50, into: <<>>, do: <<255>>)}})
      -1

      iex> EVM.Operation.EnvironmentalInformation.calldataload([0], %{exec_env: %{data: (for _ <- 1..3, into: <<>>, do: <<1>>)}})
      <<1::8, 1::8, 1::8, 0::232>> |> EVM.Helpers.decode_signed

      iex> EVM.Operation.EnvironmentalInformation.calldataload([100], %{exec_env: %{data: (for _ <- 1..3, into: <<>>, do: <<1>>)}})
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

      iex> code = <<54>>
      iex> EVM.Operation.EnvironmentalInformation.calldatacopy([0, 0, 1], %{exec_env: %EVM.ExecEnv{data: code}, machine_state: %EVM.MachineState{}})
      %{machine_state: %EVM.MachineState{active_words: 1, gas: nil, memory: <<54>> <> <<0::248>>, program_counter: 0, previously_active_words: 0, stack: []}}
  """
  @spec calldatacopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def calldatacopy([memory_start, call_data_start, length], %{exec_env: exec_env, machine_state: machine_state}) do
    if length == 0 do
      0
    else
      data = EVM.Memory.read_zeroed_memory(exec_env.data, call_data_start, length)
      machine_state = EVM.Memory.write(machine_state, memory_start, Helpers.right_pad_bytes(data))

      %{machine_state: machine_state}
    end
  end

  @doc """
  Get size of code running in current environment.

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.codesize([], %{exec_env: %{machine_code: <<0::256>>}})
      32
  """
  @spec codesize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def codesize(_args, %{exec_env: exec_env}) do
    byte_size(exec_env.machine_code)
  end

  @doc """
  Copy code running in current environment to memory.

  ## Examples

      iex> code = <<54>>
      iex> EVM.Operation.EnvironmentalInformation.codecopy([0, 0, 1], %{exec_env: %EVM.ExecEnv{machine_code: code}, machine_state: %EVM.MachineState{}})
      %{machine_state: %EVM.MachineState{active_words: 1, gas: nil, memory: <<54>> <> <<0::248>>, program_counter: 0, previously_active_words: 0, stack: []}}
  """
  @spec codecopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def codecopy([mem_offset, code_offset, length], %{exec_env: exec_env, machine_state: machine_state}) do
    if length == 0 do
      0
    else
      data = EVM.Memory.read_zeroed_memory(exec_env.machine_code, code_offset, length)
      machine_state = EVM.Memory.write(machine_state, mem_offset, Helpers.right_pad_bytes(data))

      %{machine_state: machine_state}
    end
  end

  @doc """
  Get price of gas in current environment.

  ## Examples

      iex> EVM.Operation.EnvironmentalInformation.gasprice([], %{exec_env: %{gas_price: 98}})
      98
  """
  @spec gasprice(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def gasprice(_args, %{exec_env: exec_env}) do
    exec_env.gas_price
  end

  @doc """
  Get size of an account’s code.

  ## Examples

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{account_map: %{0x01 => %{code: <<0x11, 0x22, 0x33, 0x44>>}}})
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> exec_env = %EVM.ExecEnv{account_interface: account_interface}
      iex> EVM.Operation.EnvironmentalInformation.extcodesize([0x01], %{exec_env: exec_env, state: state, machine_state: %EVM.MachineState{}}).machine_state.stack
      [4]
  """
  @spec extcodesize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def extcodesize([address], %{exec_env: exec_env, state: state, machine_state: machine_state}) do
    wrapped_address = Helpers.wrap_address(address)

    state = if Map.get(state, wrapped_address) do
      state
    else
      Map.merge(state, %{wrapped_address => %{storage: %Trie{}}})
    end

    account_code = AccountInterface.get_account_code(exec_env.account_interface, state, wrapped_address)

    extcodesize = if account_code do
      byte_size(account_code)
    else
      0
    end
    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, extcodesize)}

    %{
      machine_state: machine_state,
      state: state,
    }

  end

  @doc """
  Copy an account’s code to memory.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> code = <<54>>
      iex> account_map = %{<<0::160>> => %{code: code}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{account_map: account_map})
      iex> EVM.Operation.EnvironmentalInformation.extcodecopy([<<0::160>>, 0, 0, 1], %{exec_env: %EVM.ExecEnv{account_interface: account_interface}, machine_state: %EVM.MachineState{}, state: state})[:machine_state]
      %EVM.MachineState{active_words: 1, gas: nil, memory: <<54>> <> <<0::248>>, program_counter: 0, previously_active_words: 0, stack: []}
  """
  @spec extcodecopy(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def extcodecopy([address, code_offset, mem_offset, length], %{machine_state: machine_state, exec_env: exec_env, state: state}) do
    if length == 0 || (length + mem_offset > EVM.max_int()) do
      0
    else
      wrapped_address = Helpers.wrap_address(address)
      state = if Map.get(state, wrapped_address) do
        state
      else
        Map.merge(state, %{wrapped_address => %{storage: %Trie{}}})
      end

      account_code = AccountInterface.get_account_code(exec_env.account_interface, state, wrapped_address)

      data = EVM.Memory.read_zeroed_memory(account_code, code_offset, length)
      machine_state = EVM.Memory.write(machine_state, mem_offset, Helpers.right_pad_bytes(data))

      %{machine_state: machine_state, state: state}
    end
  end

end
