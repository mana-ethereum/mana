defmodule EVM.Operation.StackMemoryStorageAndFlow do
  alias EVM.Helpers
  alias EVM.Stack
  alias EVM.Memory
  alias MathHelper
  alias MerklePatriciaTree.Trie
  use Bitwise

  @doc """
  Remove item from stack.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.pop([55], %{stack: []})
      :noop
  """
  @spec pop(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def pop(_args, %{}) do
    # no effect, but we popped a value
    :noop
  end

  @doc """
  Load word from memory

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.mload([0], %{machine_state: %EVM.MachineState{stack: [1], memory: <<0x55::256, 0xff>>}})
      %EVM.MachineState{stack: [0x55, 1], active_words: 1, gas: nil, memory: <<0x55::256, 0xff>>, pc: 0, previously_active_words: 0}

      iex> EVM.Operation.StackMemoryStorageAndFlow.mload([1], %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256, 0xff>>}})
      %EVM.MachineState{stack: [22015], active_words: 2, gas: nil, memory: <<0x55::256, 0xff>>, pc: 0, previously_active_words: 0}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec mstore(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def mstore([offset, value], %{machine_state: machine_state}) do
    machine_state = EVM.Memory.write(machine_state, offset, Helpers.left_pad_bytes(value))

    %{machine_state: machine_state}
  end

  @doc """
  Save byte to memory.
  """
  @spec mstore8(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def mstore8([offset, value], %{machine_state: machine_state}) do
    machine_state = Memory.write(machine_state, offset, value, EVM.byte_size())

    %{machine_state: machine_state}
  end

  @doc """
  Load word from storage.

  TODO: Handle signed values?

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([0x11223344556677889900], %{state: state, stack: []})
      0x111222333444555

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([0x1234], %{state: state, stack: []})
      0x0
  """
  @spec sload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def sload([key], %{state: state=%Trie{}, stack: stack}) when is_list(stack) do
    # TODO: Consider key value encodings
    value = Trie.get(state, <<key::size(256)>>)

    if value do
      Helpers.decode_signed(value)
    else
      0
    end
  end

  @doc """
  Save word to storage.

  Defined as `σ′[Ia]_s[μ_s[0]] ≡ μ_s[1]`

  TODO: Complex gas costs, including refund.
  TODO: Handle signed values

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:store_word_test)
      iex> EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})
      %{
        state: %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :store_word_test}, root_hash: <<77, 102, 57, 173, 238, 57, 137, 237, 16, 96, 205, 248, 1, 201, 72, 65, 51, 86, 115, 120, 46, 253, 163, 44, 146, 241, 46, 237, 87, 11, 122, 100>>}
      }

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state] |> MerklePatriciaTree.Trie.Inspector.all_values()
      [
        {<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           17, 34, 51, 68, 85, 102, 119, 136, 153, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 1, 17, 34, 35, 51, 68, 69, 85>>
        }
      ]

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> EVM.Operation.StackMemoryStorageAndFlow.sstore([0x0, 0x0], %{state: MerklePatriciaTree.Trie.new(db)})[:state] |> MerklePatriciaTree.Trie.Inspector.all_values()
      [
      ]
  """
  @spec sstore(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def sstore([key, value], %{state: state}) do
    # TODO: Consider key value encodings
    if value == 0 do
      # TODO this should call Trie.delete which doesn't exist yet
      %{
        state: state
      }
    else
      %{
        state: Trie.update(state, <<key::size(256)>>, <<value::size(256)>>)
      }
    end
  end

  @doc """
  Alter the program counter.

  ## Examples

  iex> EVM.Operation.StackMemoryStorageAndFlow.jump([99], %{machine_state: %EVM.MachineState{}})
  %EVM.MachineState{pc: 99}
  """
  @spec jump(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def jump([s0], %{machine_state: machine_state}) do
    %{machine_state| pc: s0}
  end

  @doc """
  Conditionally alter the program counter.
  ## Examples

  iex> EVM.Operation.StackMemoryStorageAndFlow.jumpi([99, 1], %{machine_state: %EVM.MachineState{}})
  %EVM.MachineState{pc: 99}
  iex> EVM.Operation.StackMemoryStorageAndFlow.jumpi([99, 0], %{machine_state: %EVM.MachineState{pc: 2}})
  %EVM.MachineState{pc: 3}
  """
  @spec jumpi(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def jumpi([s0, s1], %{machine_state: machine_state}) do
    if s1 == 0 do
      %{machine_state| pc: machine_state.pc + 1}
    else
      %{machine_state| pc: s0}
    end
  end

  @doc """
  Get the value of the program counter prior to the increment corresponding to this instruction.


  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.pc([], %{machine_state: %EVM.MachineState{pc: 99}})
      99
  """
  def pc(_args, %{machine_state: %{pc: pc}}) do
    pc
  end

  @doc """
  Get the size of active memory in bytes


  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.msize([], %{machine_state: %EVM.MachineState{active_words: 1}})
      32
  """
  @spec msize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def msize(_args, %{machine_state: %{active_words: active_words}}) do
    active_words * EVM.word_size()
  end

  @doc """
  Get the amount of available gas, including the corresponding reduction for the cost of this instruction.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.gas([], %{stack: []})
      :unimplemented
  """
  @spec gas(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def gas(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Mark a valid destination for jumps.

  This is a no-op.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.jumpdest([], %{stack: []})
      :noop
  """
  @spec jumpdest(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def jumpdest(_args, %{}) do
    :noop
  end
end
