defmodule EVM.Instruction.Impl do
  @moduledoc """
  Reference implementation for all opcodes in the Ethereum VM.
  """

  require Logger
  alias EVM.Stack
  alias EVM.MachineState
  alias EVM.SubState
  alias EVM.ExecEnv
  alias MerklePatriciaTree.Trie
  use Bitwise

  @type stack_args :: [EVM.val]
  @type vm_map :: %{
    optional(:state) => Trie.t,
    optional(:stack) => Stack.t,
    optional(:machine_state) => MachineState.t,
    optional(:sub_state) => SubState.t,
    optional(:exec_env) => ExecEnv.t
  }
  @type op_result ::
    :noop | # no-op
    :unimplemented | # instruction not implemented
    EVM.val | # if it's a value it'll be pushed onto the stack
    vm_map | # updates to vm state, any nil is no-op
    MachineState.t

  @doc """
  Halts execution.

  In our implementation, this is a no-op.

  ## Examples

      iex> EVM.Instruction.Impl.stop([], %{})
      :noop
  """
  @spec stop(stack_args, vm_map) :: op_result
  def stop([], %{}) do
    :noop
  end

  @doc """
  Addition operation.

  Takes an instruction, stack arguments and the current
  state, and returns an updated state.

  The function expects the arguments for the instruction have already
  been popped off the stack.

  ## Examples

      iex> EVM.Instruction.Impl.add([1, 2], %{})
      3

      iex> EVM.Instruction.Impl.add([-1, -5], %{})
      EVM.Instruction.Impl.encode_signed(-6)

      iex> EVM.Instruction.Impl.add([0, 0], %{})
      0

      iex> EVM.Instruction.Impl.add([EVM.max_int() - 1 - 2, 1], %{})
      EVM.max_int() - 1 - 1

      iex> EVM.Instruction.Impl.add([EVM.max_int() - 1 - 2, 5], %{})
      2

      iex> EVM.Instruction.Impl.add([EVM.max_int() - 1 + 2, EVM.max_int() - 1 + 2], %{})
      2

      iex> EVM.Instruction.Impl.add([EVM.max_int() - 1, 1], %{})
      0
  """
  @spec add(stack_args, vm_map) :: op_result
  def add([s0, s1], _) do
    s0 + s1
      |> wrap_int
      |> encode_signed
  end

  @doc """
  Multiplication operation.

  ## Examples

      iex> EVM.Instruction.Impl.mul([5, 2], %{})
      10

      iex> EVM.Instruction.Impl.mul([-1, 5], %{})
      EVM.Instruction.Impl.encode_signed(-5)
  """
  @spec mul(stack_args, vm_map) :: op_result
  def mul([s0, s1], _) do
    s0 * s1
      |> wrap_int
      |> encode_signed
  end

  @doc """
  Subtraction operation.

  ## Examples

      iex> EVM.Instruction.Impl.sub([5, 2], %{})
      3

      iex> EVM.Instruction.Impl.sub([-1, 5], %{})
      EVM.Instruction.Impl.encode_signed(-6)
  """
  @spec sub(stack_args, vm_map) :: op_result
  def sub([s0, s1], _) do
    s0 - s1
      |> wrap_int
      |> encode_signed
  end

  @doc """
  Integer division operation.

  ## Examples

      iex> EVM.Instruction.Impl.div([5, 2], %{})
      2

      iex> EVM.Instruction.Impl.div([10, 2], %{})
      5

      iex> EVM.Instruction.Impl.div([10, 0], %{})
      0
  """
  def div([_s0, 0], _), do: 0
  def div([s0, s1], _) do
    Integer.floor_div(s0, s1)
      |> wrap_int
      |> encode_signed
  end

  @doc """
  Signed integer division operation (truncated).
  """
  @spec sdiv(stack_args, vm_map) :: op_result
  def sdiv([s0, s1], _) do
    case decode_signed(s1) do
      0 ->
          0
      1 ->
        s0
      -1 ->
        0 - decode_signed(s0)
      _ ->
        MathHelper.round_int((decode_signed(s0) / decode_signed(s1)))
    end
  end

  @doc """
  Modulo remainder operation.
  """
  @spec mod(stack_args, vm_map) :: op_result
  def mod([s0, s1], _) do
    if (s1 == 0), do: 0, else: rem(s0, s1)
  end

  @doc """
  Signed modulo remainder operation.
  """
  @spec smod(stack_args, vm_map) :: op_result
  def smod([_, s1], _) when s1 == 0, do: 0
  def smod([s0, s1], _) do
    rem(decode_signed(s0), decode_signed(s1))
  end

  @doc """
  Modulo addition operation.
  """
  @spec addmod(stack_args, vm_map) :: op_result
  def addmod([_, _, s2], _) when s2 == 0, do: 0
  def addmod([s0, s1, s2], _) do
    rem(s0 + s1, s2)
  end

  @doc """
  Modulo multiplication operation.
  """
  @spec mulmod(stack_args, vm_map) :: op_result
  def mulmod([_, _, s2], _) when s2 == 0, do: 0
  def mulmod([s0, s1, s2], _) do
    rem(s0 * s1, s2)
  end

  @doc """
  Exponential operation

  ## Examples

      iex> EVM.Instruction.Impl.exp([2, 3], %{})
      8

      iex> EVM.Instruction.Impl.exp([2, 257], %{})
      0
  """
  @spec exp(stack_args, vm_map) :: op_result
  def exp([s0, s1], _) do
    :crypto.mod_pow(s0, s1, EVM.max_int()) |> :binary.decode_unsigned
  end

  @doc """
  Extend length of two’s complement signed integer.
  """
  @spec signextend(stack_args, vm_map) :: op_result
  def signextend([s0, s1], _) when s0 > 31, do: s1
  def signextend([s0, s1], _) do
    if (bit_at(s1, bit_position(s0)) == 1) do
      bor(s1, EVM.max_int() - (1 <<< bit_position(s0)))
    else
      band(s1, ((1 <<< bit_position(s0)) - 1))
    end
  end

  @doc """
  Less-than comparision.

  ## Examples

      iex> EVM.Instruction.Impl.lt([55, 66], %{})
      1

      iex> EVM.Instruction.Impl.lt([66, 55], %{})
      0

      iex> EVM.Instruction.Impl.lt([55, 55], %{})
      0
  """
  @spec lt(stack_args, vm_map) :: op_result
  def lt([s0, s1], _) do
    if s0 < s1, do: 1, else: 0
  end

  @doc """
  Greater-than comparision.

  ## Examples

      iex> EVM.Instruction.Impl.gt([55, 66], %{})
      0

      iex> EVM.Instruction.Impl.gt([66, 55], %{})
      1

      iex> EVM.Instruction.Impl.gt([55, 55], %{})
      0
  """
  @spec gt(stack_args, vm_map) :: op_result
  def gt([s0, s1], _) do
    if s0 > s1, do: 1, else: 0
  end

  @doc """
  Signed less-than comparision.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.slt([], %{stack: []})
      :unimplemented
  """
  @spec slt(stack_args, vm_map) :: op_result
  def slt(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Signed greater-than comparision

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.sgt([], %{stack: []})
      :unimplemented
  """
  @spec sgt(stack_args, vm_map) :: op_result
  def sgt(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Equality comparision.

  ## Examples

      iex> EVM.Instruction.Impl.eq([55, 1], %{stack: []})
      %{stack: [0]}

      iex> EVM.Instruction.Impl.eq([55, 55], %{stack: []})
      %{stack: [1]}

      iex> EVM.Instruction.Impl.eq([0, 0], %{stack: []})
      %{stack: [1]}
  """
  @spec eq(stack_args, vm_map) :: op_result
  def eq([s0, s1], %{stack: stack}) do
    stack |> push(if s0 == s1, do: 1, else: 0)
  end

  @doc """
  Simple not operator.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.iszero([], %{stack: []})
      :unimplemented
  """
  @spec iszero(stack_args, vm_map) :: op_result
  def iszero(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise AND operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.and_([], %{stack: []})
      :unimplemented
  """
  @spec and_(stack_args, vm_map) :: op_result
  def and_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise OR operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.or_([], %{stack: []})
      :unimplemented
  """
  @spec or_(stack_args, vm_map) :: op_result
  def or_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise XOR operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.xor_([], %{stack: []})
      :unimplemented
  """
  @spec xor_(stack_args, vm_map) :: op_result
  def xor_(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Bitwise NOT operation.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.not_([EVM.Instruction.Impl.encode_signed(-1)], %{stack: []})
      0
  """
  @spec not_(stack_args, vm_map) :: op_result
  def not_([s0], _) do
    encode_signed(bnot(s0))
  end

  @doc """
  Retrieve single byte from word.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.byte([], %{stack: []})
      :unimplemented
  """
  @spec byte(stack_args, vm_map) :: op_result
  def byte(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Compute Keccak-256 hash.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.sha3([], %{stack: []})
      :unimplemented
  """
  @spec sha3(stack_args, vm_map) :: op_result
  def sha3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get address of currently executing account.

  ## Examples

      iex> EVM.Instruction.Impl.address([], %{stack: [], exec_env: %EVM.ExecEnv{address: <<01, 00>>}})
      %{stack: [0x100]}
  """
  @spec address(stack_args, vm_map) :: op_result
  def address(_args, %{stack: stack, exec_env: exec_env}) do
    stack |> push(exec_env.address |> :binary.decode_unsigned)
  end

  @doc """
  Get balance of the given account.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.balance([], %{stack: []})
      :unimplemented
  """
  @spec balance(stack_args, vm_map) :: op_result
  def balance(_args, %{stack: _stack}) do
    #   # stack |> state
    #   # access state data
    :unimplemented
  end

  @doc """
  Get execution origination address.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.origin([], %{stack: []})
      :unimplemented
  """
  @spec origin(stack_args, vm_map) :: op_result
  def origin(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get caller address.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.caller([], %{stack: []})
      :unimplemented
  """
  @spec caller(stack_args, vm_map) :: op_result
  def caller(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get deposited value by the instruction/transaction responsible for this execution.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.callvalue([], %{stack: []})
      :unimplemented
  """
  @spec callvalue(stack_args, vm_map) :: op_result
  def callvalue(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get input data of current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.calldataload([], %{stack: []})
      :unimplemented
  """
  @spec calldataload(stack_args, vm_map) :: op_result
  def calldataload(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get size of input data in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.calldatasize([], %{stack: []})
      :unimplemented
  """
  @spec calldatasize(stack_args, vm_map) :: op_result
  def calldatasize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy input data in current environment to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.calldatacopy([], %{stack: []})
      :unimplemented
  """
  @spec calldatacopy(stack_args, vm_map) :: op_result
  def calldatacopy(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get size of code running in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.codesize([], %{stack: []})
      :unimplemented
  """
  @spec codesize(stack_args, vm_map) :: op_result
  def codesize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy code running in current environment to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.codecopy([], %{stack: []})
      :unimplemented
  """
  @spec codecopy(stack_args, vm_map) :: op_result
  def codecopy(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get price of gas in current environment.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.gasprice([], %{stack: []})
      :unimplemented
  """
  @spec gasprice(stack_args, vm_map) :: op_result
  def gasprice(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get size of an account’s code.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.extcodesize([], %{stack: []})
      :unimplemented
  """
  @spec extcodesize(stack_args, vm_map) :: op_result
  def extcodesize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Copy an account’s code to memory.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.extcodecopy([], %{stack: []})
      :unimplemented
  """
  @spec extcodecopy(stack_args, vm_map) :: op_result
  def extcodecopy(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the hash of one of the 256 most recent complete blocks

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.blockhash([], %{stack: []})
      :unimplemented
  """
  @spec blockhash(stack_args, vm_map) :: op_result
  def blockhash(_args, %{stack: _stack}) do
    # TODO: from header of block and ... ?
    :unimplemented
  end

  @doc """
  Get the block’s beneficiary address

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.coinbase([], %{stack: []})
      :unimplemented
  """
  @spec coinbase(stack_args, vm_map) :: op_result
  def coinbase(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s timestamp

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.timestamp([], %{stack: []})
      :unimplemented
  """
  @spec timestamp(stack_args, vm_map) :: op_result
  def timestamp(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s number.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.number([], %{stack: []})
      :unimplemented
  """
  @spec number(stack_args, vm_map) :: op_result
  def number(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s difficulty.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.difficulty([], %{stack: []})
      :unimplemented
  """
  @spec difficulty(stack_args, vm_map) :: op_result
  def difficulty(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the block’s gas limit.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.gaslimit([], %{stack: []})
      :unimplemented
  """
  @spec gaslimit(stack_args, vm_map) :: op_result
  def gaslimit(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Remove item from stack.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.pop([55], %{stack: []})
      :noop
  """
  @spec pop(stack_args, vm_map) :: op_result
  def pop(_args, %{}) do
    # no effect, but we popped a value
    :noop
  end

  @doc """
  Load word from memory

  ## Examples

      iex> EVM.Instruction.Impl.mload([0], %{machine_state: %EVM.MachineState{stack: [1], memory: <<0x55::256, 0xff>>}})
      %{machine_state: %EVM.MachineState{stack: [0x55, 1], memory: <<0x55::256, 0xff>>, active_words: 1}}

      iex> EVM.Instruction.Impl.mload([1], %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256, 0xff>>}})
      %{machine_state: %EVM.MachineState{stack: [22015], memory: <<0x55::256, 0xff>>, active_words: 2}}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mload(stack_args, vm_map) :: op_result
  def mload([offset], %{machine_state: machine_state}) do
    {v, machine_state} = EVM.Memory.read(machine_state, offset, 32)

    %{machine_state: machine_state |> push(v |> decode)}
  end

  @doc """
  Save word to memory.

  ## Examples

      iex> EVM.Instruction.Impl.mstore([0, 0x55], %{machine_state: %EVM.MachineState{stack: [], memory: <<>>}})
      %{machine_state: %EVM.MachineState{stack: [], memory: <<0x55::256>>, active_words: 1}}

      iex> EVM.Instruction.Impl.mstore([1, 0x55], %{machine_state: %EVM.MachineState{stack: [], memory: <<>>}})
      %{machine_state: %EVM.MachineState{stack: [], memory: <<0, 0x55::256>>, active_words: 2}}

      # TODO: Add a test for overflow, etc.
      # TODO: Handle sign?
  """
  @spec mstore(stack_args, vm_map) :: op_result
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
  @spec mstore8(stack_args, vm_map) :: op_result
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
      iex> state = EVM.Instruction.Impl.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Instruction.Impl.sload([0x11223344556677889900], %{state: state, stack: []})
      %{
        stack: [0x111222333444555]
      }

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = EVM.Instruction.Impl.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state]
      iex> EVM.Instruction.Impl.sload([0x1234], %{state: state, stack: []})
      %{
        stack: [0x0]
      }
  """
  @spec sload(stack_args, vm_map) :: op_result
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
      iex> EVM.Instruction.Impl.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})
      %{
        state: %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :store_word_test}, root_hash: <<128, 58, 53, 102, 7, 182, 120, 131, 145, 91, 222, 83, 56, 42, 251, 168, 203, 138, 130, 246, 76, 122, 110, 218, 183, 131, 33, 205, 154, 136, 194, 212>>}
      }

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> EVM.Instruction.Impl.sstore([0x11223344556677889900, 0x111222333444555], %{state: MerklePatriciaTree.Trie.new(db)})[:state] |> MerklePatriciaTree.Trie.Inspector.all_values()
      [
        {<<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           17, 34, 51, 68, 85, 102, 119, 136, 153, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 1, 17, 34, 35, 51, 68, 69, 85>>
        }
      ]

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> EVM.Instruction.Impl.sstore([0x0, 0x0], %{state: MerklePatriciaTree.Trie.new(db)})[:state] |> MerklePatriciaTree.Trie.Inspector.all_values()
      [
      ]
  """
  @spec sstore(stack_args, vm_map) :: op_result
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

      iex> EVM.Instruction.Impl.jump([], %{stack: []})
      :noop
  """
  @spec jump(stack_args, vm_map) :: op_result
  def jump(_args, %{}) do
    :noop
  end

  @doc """
  Conditionally alter the program counter.

  This is a no-op as it's handled elsewhere in the VM.

  ## Examples

      iex> EVM.Instruction.Impl.jumpi([], %{stack: []})
      :noop
  """
  @spec jumpi(stack_args, vm_map) :: op_result
  def jumpi(_args, %{}) do
    :noop
  end

  @doc """
  Get the value of the program counter prior to the increment corresponding to this instruction.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.pc([], %{stack: []})
      :unimplemented
  """
  @spec pc(stack_args, vm_map) :: op_result
  def pc(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the size of active memory in bytes

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.msize([], %{stack: []})
      :unimplemented
  """
  @spec msize(stack_args, vm_map) :: op_result
  def msize(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Get the amount of available gas, including the corresponding reduction for the cost of this instruction.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.gas([], %{stack: []})
      :unimplemented
  """
  @spec gas(stack_args, vm_map) :: op_result
  def gas(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Mark a valid destination for jumps.

  This is a no-op.

  ## Examples

      iex> EVM.Instruction.Impl.jumpdest([], %{stack: []})
      :noop
  """
  @spec jumpdest(stack_args, vm_map) :: op_result
  def jumpdest(_args, %{}) do
    :noop
  end

  @doc """
  Place n-byte item on stack

  ## Examples

      iex> EVM.Instruction.Impl.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 1}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x12], pc: 1}}

      iex> EVM.Instruction.Impl.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 2}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x13], pc: 2}}

      iex> EVM.Instruction.Impl.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 3}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x00], pc: 3}}

      iex> EVM.Instruction.Impl.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 4}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x00], pc: 4}}

      iex> EVM.Instruction.Impl.push_n(1, [], %{machine_state: %EVM.MachineState{stack: [], pc: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x00], pc: 100}}

      iex> EVM.Instruction.Impl.push_n(6, [], %{machine_state: %EVM.MachineState{stack: [], pc: 0}, exec_env: %EVM.ExecEnv{machine_code: <<0xFF, 0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [17665503723520], pc: 0}}

      iex> EVM.Instruction.Impl.push_n(16, [], %{machine_state: %EVM.MachineState{stack: [], pc: 100}, exec_env: %EVM.ExecEnv{machine_code: <<0x10, 0x11, 0x12, 0x13>>}})
      %{machine_state: %EVM.MachineState{stack: [0x00], pc: 100}}
  """
  @spec push_n(integer(), stack_args, vm_map) :: op_result
  def push_n(n, [], %{machine_state: machine_state, exec_env: exec_env}) do
    val = EVM.Memory.read_zeroed_memory(exec_env.machine_code, machine_state.pc + 1, n) |> decode

    %{machine_state: machine_state |> push(val)}
  end

  @doc """
  Duplicate 1st stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup1([], %{stack: []})
      :unimplemented
  """
  @spec dup1(stack_args, vm_map) :: op_result
  def dup1(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 2nd stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup2([], %{stack: []})
      :unimplemented
  """
  @spec dup2(stack_args, vm_map) :: op_result
  def dup2(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 3rd stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup3([], %{stack: []})
      :unimplemented
  """
  @spec dup3(stack_args, vm_map) :: op_result
  def dup3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 4th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup4([], %{stack: []})
      :unimplemented
  """
  @spec dup4(stack_args, vm_map) :: op_result
  def dup4(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 5th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup5([], %{stack: []})
      :unimplemented
  """
  @spec dup5(stack_args, vm_map) :: op_result
  def dup5(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 6th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup6([], %{stack: []})
      :unimplemented
  """
  @spec dup6(stack_args, vm_map) :: op_result
  def dup6(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 7th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup7([], %{stack: []})
      :unimplemented
  """
  @spec dup7(stack_args, vm_map) :: op_result
  def dup7(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 8th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup8([], %{stack: []})
      :unimplemented
  """
  @spec dup8(stack_args, vm_map) :: op_result
  def dup8(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 9th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup9([], %{stack: []})
      :unimplemented
  """
  @spec dup9(stack_args, vm_map) :: op_result
  def dup9(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 10th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup10([], %{stack: []})
      :unimplemented
  """
  @spec dup10(stack_args, vm_map) :: op_result
  def dup10(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 11th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup11([], %{stack: []})
      :unimplemented
  """
  @spec dup11(stack_args, vm_map) :: op_result
  def dup11(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 12th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup12([], %{stack: []})
      :unimplemented
  """
  @spec dup12(stack_args, vm_map) :: op_result
  def dup12(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 13th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup13([], %{stack: []})
      :unimplemented
  """
  @spec dup13(stack_args, vm_map) :: op_result
  def dup13(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 14th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup14([], %{stack: []})
      :unimplemented
  """
  @spec dup14(stack_args, vm_map) :: op_result
  def dup14(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 15th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup15([], %{stack: []})
      :unimplemented
  """
  @spec dup15(stack_args, vm_map) :: op_result
  def dup15(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Duplicate 16th stack item.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.dup16([], %{stack: []})
      :unimplemented
  """
  @spec dup16(stack_args, vm_map) :: op_result
  def dup16(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 1st and 2nd stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap1([1,2], %{stack: []})
      %{stack: [2,1]}
  """
  @spec swap1(stack_args, vm_map) :: op_result
  def swap1([s0, s1], %{stack: stack}) do
    stack |> push(s0) |> Map.get(:stack) |> push(s1)
  end

  @doc """
  Exchange 2nd and 3rd stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap2([], %{stack: []})
      :unimplemented
  """
  @spec swap2(stack_args, vm_map) :: op_result
  def swap2(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 3rd and 4th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap3([], %{stack: []})
      :unimplemented
  """
  @spec swap3(stack_args, vm_map) :: op_result
  def swap3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 4th and 5th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap4([], %{stack: []})
      :unimplemented
  """
  @spec swap4(stack_args, vm_map) :: op_result
  def swap4(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 5th and 6th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap5([], %{stack: []})
      :unimplemented
  """
  @spec swap5(stack_args, vm_map) :: op_result
  def swap5(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 6th and 7th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap6([], %{stack: []})
      :unimplemented
  """
  @spec swap6(stack_args, vm_map) :: op_result
  def swap6(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 7th and 8th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap7([], %{stack: []})
      :unimplemented
  """
  @spec swap7(stack_args, vm_map) :: op_result
  def swap7(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 8th and 9th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap8([], %{stack: []})
      :unimplemented
  """
  @spec swap8(stack_args, vm_map) :: op_result
  def swap8(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 9th and 10th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap9([], %{stack: []})
      :unimplemented
  """
  @spec swap9(stack_args, vm_map) :: op_result
  def swap9(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 10th and 11th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap10([], %{stack: []})
      :unimplemented
  """
  @spec swap10(stack_args, vm_map) :: op_result
  def swap10(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 11th and 12th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap11([], %{stack: []})
      :unimplemented
  """
  @spec swap11(stack_args, vm_map) :: op_result
  def swap11(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 12th and 13th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap12([], %{stack: []})
      :unimplemented
  """
  @spec swap12(stack_args, vm_map) :: op_result
  def swap12(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 13th and 14th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap13([], %{stack: []})
      :unimplemented
  """
  @spec swap13(stack_args, vm_map) :: op_result
  def swap13(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 14th and 15th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap14([], %{stack: []})
      :unimplemented
  """
  @spec swap14(stack_args, vm_map) :: op_result
  def swap14(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 15th and 16th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap15([], %{stack: []})
      :unimplemented
  """
  @spec swap15(stack_args, vm_map) :: op_result
  def swap15(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Exchange 16th and 17th stack items.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.swap16([], %{stack: []})
      :unimplemented
  """
  @spec swap16(stack_args, vm_map) :: op_result
  def swap16(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with no topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.log0([], %{stack: []})
      :unimplemented
  """
  @spec log0(stack_args, vm_map) :: op_result
  def log0(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with one topic.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.log1([], %{stack: []})
      :unimplemented
  """
  @spec log1(stack_args, vm_map) :: op_result
  def log1(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with two topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.log2([], %{stack: []})
      :unimplemented
  """
  @spec log2(stack_args, vm_map) :: op_result
  def log2(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with three topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.log3([], %{stack: []})
      :unimplemented
  """
  @spec log3(stack_args, vm_map) :: op_result
  def log3(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Append log record with four topics.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.log4([], %{stack: []})
      :unimplemented
  """
  @spec log4(stack_args, vm_map) :: op_result
  def log4(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Create a new account with associated code.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.create([], %{stack: []})
      :unimplemented
  """
  @spec create(stack_args, vm_map) :: op_result
  def create(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Message-call into an account.,

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.call([], %{stack: []})
      :unimplemented
  """
  @spec call(stack_args, vm_map) :: op_result
  def call(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Message-call into this account with an alternative account’s code.,

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.callcode([], %{stack: []})
      :unimplemented
  """
  @spec callcode(stack_args, vm_map) :: op_result
  def callcode(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Halt execution returning output data,

  ## Examples

      iex> EVM.Instruction.Impl.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 0}})
      %EVM.MachineState{active_words: 2}

      iex> EVM.Instruction.Impl.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 5}})
      %EVM.MachineState{active_words: 5}
  """
  @spec return(stack_args, vm_map) :: op_result
  def return([_mem_start, mem_end], %{machine_state: machine_state}) do
    # We may have to bump up number of active words
    machine_state |> MachineState.maybe_set_active_words(EVM.Memory.get_active_words(mem_end))
  end

  @doc """
  Message-call into this account with an alternative account’s code, but persisting the current values for sender and value.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.delegatecall([], %{stack: []})
      :unimplemented
  """
  @spec delegatecall(stack_args, vm_map) :: op_result
  def delegatecall(_args, %{stack: _stack}) do
    :unimplemented
  end

  @doc """
  Halt execution and register account for later deletion.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Instruction.Impl.suicide([], %{stack: []})
      :unimplemented
  """
  @spec suicide(stack_args, vm_map) :: op_result
  def suicide(_args, %{stack: _stack}) do
    :unimplemented
  end

  # Helper function to push to the stack within machine_state.
  @spec push(MachineState.t | Stack.t, EVM.val) :: op_result
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

  @spec wrap_int(integer()) :: EVM.val
  defp wrap_int(n) when n > 0, do: band(n, EVM.max_int() - 1)
  defp wrap_int(n), do: n


  # TODO: signed?
  @spec decode(binary()) :: EVM.val
  defp decode(bin), do: :binary.decode_unsigned(bin) |> wrap_int

  def decode_signed(n) do
    <<sign :: size(1), _ :: bitstring>> = :binary.encode_unsigned(n)
    if sign == 0, do: n, else: n - EVM.max_int()
  end

  def encode_signed(n) when n < 0, do: EVM.max_int() - abs(n)
  def encode_signed(n), do: n
  defp bit_at(n, at), do: band((bsr(n, at)), 1)
  defp bit_position(byte_position), do: byte_position * 8  + 7

end
