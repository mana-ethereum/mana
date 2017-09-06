defmodule EVM.Operation.StackMemoryStorageAndFlow do
  alias EVM.Stack
  alias EVM.MachineState
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
      %{machine_state: %EVM.MachineState{stack: [0x55, 1], memory: <<0x55::256, 0xff>>, active_words: 1}}

      iex> EVM.Operation.StackMemoryStorageAndFlow.mload([1], %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256, 0xff>>}})
      %{machine_state: %EVM.MachineState{stack: [22015], memory: <<0x55::256, 0xff>>, active_words: 2}}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def mload([offset], %{machine_state: machine_state}) do
    {v, machine_state} = EVM.Memory.read(machine_state, offset, 32)

    %{machine_state: machine_state |> push(v |> decode)}
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
    data = value |> wrap_int |> :binary.encode_unsigned()
    padding_bits = ( 32 - byte_size(data) ) * 8 # since we ran mod, we can't run over
    padded_data = <<0::size(padding_bits)>> <> data

    machine_state = EVM.Memory.write(machine_state, offset, padded_data)

    %{machine_state: machine_state}
  end

  @doc """
  Save byte to memory.
  """
  @spec mstore8(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def mstore8([offset, value], %{machine_state: machine_state}) do
    data = value |> wrap_int |> :binary.encode_unsigned()
    padding_bits = ( 32 - byte_size(data) ) * 8 # since we ran mod, we can't run over
    padded_data = <<0::size(padding_bits)>> <> data

    machine_state = EVM.Memory.write(machine_state, offset, padded_data)

    %{machine_state: machine_state}
  end

  @doc """
  Load word from storage.

  TODO: Handle signed values?

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([0x11223344556677889900], %{state: state, stack: []})
      %{
        stack: [0x111222333444555]
      }

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = EVM.Operation.StackMemoryStorageAndFlow.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Operation.StackMemoryStorageAndFlow.sload([0x1234], %{state: state, stack: []})
      %{
        stack: [0x0]
      }
  """
  @spec sload(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def sload([key], %{state: state=%Trie{}, stack: stack}) when is_list(stack) do
    # TODO: Consider key value encodings
    stack_value = case Trie.get(state, <<key::size(256)>>) do
      nil -> 0
      value -> :binary.decode_unsigned(value)
    end

    stack |> push(stack_value)
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

  This is a no-op as it's handled elsewhere in the VM.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.jump([], %{stack: []})
      :noop
  """
  @spec jump(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def jump(_args, %{}) do
    :noop
  end

  @doc """
  Conditionally alter the program counter.

  This is a no-op as it's handled elsewhere in the VM.

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.jumpi([], %{stack: []})
      :noop
  """
  @spec jumpi(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def jumpi(_args, %{}) do
    :noop
  end

  @doc """
  Get the value of the program counter prior to the increment corresponding to this instruction.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.pc([], %{stack: []})
      :unimplemented
  """
  @spec pc(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def pc(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the size of active memory in bytes

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.StackMemoryStorageAndFlow.msize([], %{stack: []})
      :unimplemented
  """
  @spec msize(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def msize(_args, %{stack: _stack}) do
    :unimplemented
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

  # Helper function to push to the stack within machine_state.
  @spec push(MachineState.t | Stack.t, EVM.val) :: Operation.op_result
  defp push(machine_state=%MachineState{}, val) do
    %{
      machine_state |
      stack: machine_state.stack
        |> Stack.push(val |> encode_signed)
    }
  end

  # Helper function to just return an updated stack
  defp push(stack, val) when is_list(stack) do
    %{stack: Stack.push(stack, val |> encode_signed)}
  end

  # TODO: signed?
  @spec decode(binary()) :: EVM.val
  defp decode(bin), do: :binary.decode_unsigned(bin) |> wrap_int

  def decode_signed(n) do
    <<sign :: size(1), _ :: bitstring>> = :binary.encode_unsigned(n)
    if sign == 0, do: n, else: n - EVM.max_int()
  end

  def wrap_int(n) when n > 0, do: band(n, EVM.max_int() - 1)
  def wrap_int(n), do: n

  @doc """
  Encodes signed ints using twos compliment

  ## Examples

      iex> EVM.Helpers.encode_signed(1)
      1

      iex> EVM.Helpers.encode_signed(-1)
      EVM.max_int() - 1
  """
  @spec wrap_int(integer()) :: EVM.val
  def encode_signed(n) when n < 0, do: EVM.max_int() - abs(n)
  def encode_signed(n), do: n
end
