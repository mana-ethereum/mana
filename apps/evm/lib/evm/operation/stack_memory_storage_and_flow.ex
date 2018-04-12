defmodule EVM.Operation.StackMemoryStorageAndFlow do
  alias EVM.Helpers
  alias EVM.Memory
  alias EVM.Stack
  alias EVM.ExecEnv
  alias MathHelper
  alias EVM.Operation
  use Bitwise

  @doc """
  Remove item from stack.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.pop([55], %{stack: []})
      :noop
  """
  @spec pop(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def pop(_args, %{}) do
    # no effect, but we popped a value
    :noop
  end

  @doc """
  Load word from memory

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.mload([0], %{machine_state: %EVM.MachineState{stack: [1], memory: <<0x55::256, 0xff>>}})
      %EVM.MachineState{stack: [0x55, 1], active_words: 1, gas: nil, memory: <<0x55::256, 0xff>>, program_counter: 0, previously_active_words: 0}

      iex> EVM.Operation.StackMemoryStorageAndFlow.mload([1], %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256, 0xff>>}})
      %EVM.MachineState{stack: [22015], active_words: 2, gas: nil, memory: <<0x55::256, 0xff>>, program_counter: 0, previously_active_words: 0}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mload(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def mload([offset], %{machine_state: machine_state}) do
    {value, machine_state} = EVM.Memory.read(machine_state, offset, 32)

    %{machine_state | stack: Stack.push(machine_state.stack, :binary.decode_unsigned(value))}
  end

  @doc """
  Save word to memory.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.mstore([0, 0x55], %{machine_state: %EVM.MachineState{stack: [], memory: <<>>}})
      %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256>>, active_words: 1}}

      iex> EVM.Operation.StackMemoryStorageAndFlow.mstore([1, 0x55], %{machine_state: %EVM.MachineState{stack: [], memory: <<>>}})
      %{machine_state: %EVM.MachineState{stack: [], memory: <<0, 0x55::256>>, active_words: 2}}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mstore(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def mstore([offset, value], %{machine_state: machine_state}) do
    machine_state = EVM.Memory.write(machine_state, offset, Helpers.left_pad_bytes(value))

    %{machine_state: machine_state}
  end

  @doc """
  Save byte to memory.
  """
  @spec mstore8(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def mstore8([offset, value], %{machine_state: machine_state}) do
    machine_state = Memory.write(machine_state, offset, value, EVM.byte_size())

    %{machine_state: machine_state}
  end

  @doc """
  Load word from storage.

  TODO: Handle signed values?

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> key = 0x11223344556677889900
      iex> value = 0x111222333444555
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> account_interface = EVM.Operation.StackMemoryStorageAndFlow.sstore([key, value], %{exec_env: %EVM.ExecEnv{address: address, account_interface: account_interface}})[:exec_env].account_interface
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([key], %{exec_env: %EVM.ExecEnv{account_interface: account_interface, address: address}})
      0x111222333444555


      iex> address = 0x0000000000000000000000000000000000000001
      iex> key = 0x11223344556677889900
      iex> other_key = 0x1234
      iex> value = 0x111222333444555
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> account_interface = EVM.Operation.StackMemoryStorageAndFlow.sstore([key, value], %{exec_env: %EVM.ExecEnv{address: address, account_interface: account_interface}})[:exec_env].account_interface
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([other_key], %{exec_env: %EVM.ExecEnv{account_interface: account_interface}})
      0x0
  """
  @spec sload(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def sload([key], %{exec_env: exec_env}) do
    case ExecEnv.get_storage(exec_env, key) do
      :account_not_found -> 0
      :key_not_found -> 0
      {:ok, value} -> value
    end
  end

  @doc """
  Save word to storage.

  Defined as `σ′[Ia]_s[μ_s[0]] ≡ μ_s[1]`

  TODO: Complex gas costs, including refund.
  TODO: Handle signed values

  ## Examples


      iex> address = 0x0000000000000000000000000000000000000001
      iex> key = 0x11223344556677889900
      iex> value = 0x111222333444555
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> EVM.Operation.StackMemoryStorageAndFlow.sstore([key, value], %{exec_env: %EVM.ExecEnv{address: address, account_interface: account_interface}})[:exec_env].account_interface
      ...> |> EVM.Interface.AccountInterface.get_storage(address, key)
      {:ok, 0x111222333444555}

      iex> address = 0x0000000000000000000000000000000000000001
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> EVM.Operation.StackMemoryStorageAndFlow.sstore([0x0, 0x0], %{exec_env: %EVM.ExecEnv{address: address, account_interface: account_interface}})[:exec_env].account_interface |> EVM.Interface.AccountInterface.dump_storage()
      %{1 => %{}}

  """
  @spec sstore(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def sstore([key, value], %{exec_env: exec_env}) do
    exec_env = ExecEnv.put_storage(exec_env, key, value)

    %{exec_env: exec_env}
  end

  @doc """
  Jumps are handled by `EVM.ProgramCounter.next`. This is a noop.

  """
  @spec jump(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def jump(_args, _vm_map) do
    :noop
  end

  @doc """
  Jumps are handled by `EVM.ProgramCounter.next`. This is a noop.

  """
  @spec jumpi(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def jumpi(_args, _vm_map) do
    :noop
  end

  @doc """
  Get the value of the program counter prior to the increment corresponding to this instruction.


  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.pc([], %{machine_state: %EVM.MachineState{program_counter: 99}})
      99
  """
  def pc(_args, %{machine_state: %{program_counter: program_counter}}) do
    program_counter
  end

  @doc """
  Get the size of active memory in bytes


  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.msize([], %{machine_state: %EVM.MachineState{active_words: 1}})
      32
  """
  @spec msize(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def msize(_args, %{machine_state: %{active_words: active_words}}) do
    active_words * EVM.word_size()
  end

  @doc """
  Get the amount of available gas, including the corresponding reduction for the cost of this instruction.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.gas([], %{machine_state: %{gas: 99}})
      99
  """
  @spec gas(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def gas(_args, %{machine_state: machine_state}) do
    machine_state.gas
  end

  @doc """
  Mark a valid destination for jumps.

  This is a no-op.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.jumpdest([], %{stack: []})
      :noop
  """
  @spec jumpdest(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def jumpdest(_args, %{}) do
    :noop
  end
end
