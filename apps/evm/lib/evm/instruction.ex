defmodule EVM.Instruction do
  @moduledoc """
  Code to handle encoding and decoding
  instructions from opcodes.
  """

  alias EVM.ExecEnv
  alias EVM.MachineState
  alias EVM.SubState

  require Logger

  @type instruction :: atom()
  @type opcode :: byte()

  @instructions [
    %EVM.Instruction.Metadata{id: 0x00, sym: :stop, d: 0, a: 0, description: "Halts execution"},
    %EVM.Instruction.Metadata{id: 0x01, sym: :add, d: 2, a: 1, description: "Addition operation"},
    %EVM.Instruction.Metadata{id: 0x02, sym: :mul, d: 2, a: 1, description: "Multiplication operation."},
    %EVM.Instruction.Metadata{id: 0x03, sym: :sub, d: 2, a: 1, description: "Subtraction operation."},
    %EVM.Instruction.Metadata{id: 0x04, sym: :div, d: 2, a: 1, description: "Integer division operation."},
    %EVM.Instruction.Metadata{id: 0x05, sym: :sdiv, d: 2, a: 1, description: "Signed integer division operation (truncated)."},
    %EVM.Instruction.Metadata{id: 0x06, sym: :mod, d: 2, a: 1, description: "Modulo remainder operation."},
    %EVM.Instruction.Metadata{id: 0x07, sym: :smod, d: 2, a: 1, description: "Signed modulo remainder operation."},
    %EVM.Instruction.Metadata{id: 0x08, sym: :addmod, d: 3, a: 1, description: "Modulo addition operation."},
    %EVM.Instruction.Metadata{id: 0x09, sym: :mulmod, d: 3, a: 1, description: "Modulo multiplication operation."},
    %EVM.Instruction.Metadata{id: 0x0a, sym: :exp, d: 2, a: 1, description: "Exponential operation"},
    %EVM.Instruction.Metadata{id: 0x0b, sym: :signextend, d: 2, a: 1, description: "Extend length of two’s complement signed integer."},
    %EVM.Instruction.Metadata{id: 0x10, sym: :lt, d: 2, a: 1, description: "Less-than comparision."},
    %EVM.Instruction.Metadata{id: 0x11, sym: :gt, d: 2, a: 1, description: "Greater-than comparision."},
    %EVM.Instruction.Metadata{id: 0x12, sym: :slt, d: 2, a: 1, description: "Signed less-than comparision."},
    %EVM.Instruction.Metadata{id: 0x13, sym: :sgt, d: 2, a: 1, description: "Signed greater-than comparision"},
    %EVM.Instruction.Metadata{id: 0x14, sym: :eq, d: 2, a: 1, description: "Equality comparision."},
    %EVM.Instruction.Metadata{id: 0x15, sym: :iszero, d: 1, a: 1, description: "Simple not operator."},
    %EVM.Instruction.Metadata{id: 0x16, sym: :and_, d: 2, a: 1, description: "Bitwise AND operation."},
    %EVM.Instruction.Metadata{id: 0x17, sym: :or_, d: 2, a: 1, description: "Bitwise OR operation."},
    %EVM.Instruction.Metadata{id: 0x18, sym: :xor_, d: 2, a: 1, description: "Bitwise XOR operation."},
    %EVM.Instruction.Metadata{id: 0x19, sym: :not_, d: 1, a: 1, description: "Bitwise NOT operation."},
    %EVM.Instruction.Metadata{id: 0x1a, sym: :byte, d: 2, a: 1, description: "Retrieve single byte from word."},
    %EVM.Instruction.Metadata{id: 0x20, sym: :sha3, d: 2, a: 1, description: "Compute Keccak-256 hash."},
    %EVM.Instruction.Metadata{id: 0x30, sym: :address, d: 0, a: 1, description: "Get address of currently executing account."},
    %EVM.Instruction.Metadata{id: 0x31, sym: :balance, d: 1, a: 1, description: "Get balance of the given account."},
    %EVM.Instruction.Metadata{id: 0x32, sym: :origin, d: 0, a: 1, description: "Get execution origination address."},
    %EVM.Instruction.Metadata{id: 0x33, sym: :caller, d: 0, a: 1, description: "Get caller address."},
    %EVM.Instruction.Metadata{id: 0x34, sym: :callvalue, d: 0, a: 1, description: "Get deposited value by the instruction/transaction responsible for this execution."},
    %EVM.Instruction.Metadata{id: 0x35, sym: :calldataload, d: 1, a: 1, description: "Get input data of current environment."},
    %EVM.Instruction.Metadata{id: 0x36, sym: :calldatasize, d: 0, a: 1, description: "Get size of input data in current environment."},
    %EVM.Instruction.Metadata{id: 0x37, sym: :calldatacopy, d: 3, a: 0, description: "Copy input data in current environment to memory."},
    %EVM.Instruction.Metadata{id: 0x38, sym: :codesize, d: 0, a: 1, description: "Get size of code running in current environment."},
    %EVM.Instruction.Metadata{id: 0x39, sym: :codecopy, d: 3, a: 0, description: "Copy code running in current environment to memory."},
    %EVM.Instruction.Metadata{id: 0x3a, sym: :gasprice, d: 0, a: 1, description: "Get price of gas in current environment."},
    %EVM.Instruction.Metadata{id: 0x3b, sym: :extcodesize, d: 1, a: 1, description: "Get size of an account’s code."},
    %EVM.Instruction.Metadata{id: 0x3c, sym: :extcodecopy, d: 4, a: 0, description: "Copy an account’s code to memory."},
    %EVM.Instruction.Metadata{id: 0x40, sym: :blockhash, d: 1, a: 1, description: "Get the hash of one of the 256 most recent complete blocks"},
    %EVM.Instruction.Metadata{id: 0x41, sym: :coinbase, d: 0, a: 1, description: "Get the block’s beneficiary address"},
    %EVM.Instruction.Metadata{id: 0x42, sym: :timestamp, d: 0, a: 1, description: "Get the block’s timestamp"},
    %EVM.Instruction.Metadata{id: 0x43, sym: :number, d: 0, a: 1, description: "Get the block’s number."},
    %EVM.Instruction.Metadata{id: 0x44, sym: :difficulty, d: 0, a: 1, description: "Get the block’s difficulty."},
    %EVM.Instruction.Metadata{id: 0x45, sym: :gaslimit, d: 0, a: 1, description: "Get the block’s gas limit."},
    %EVM.Instruction.Metadata{id: 0x50, sym: :pop, d: 1, a: 0, description: "Remove item from stack."},
    %EVM.Instruction.Metadata{id: 0x51, sym: :mload, d: 1, a: 1, description: "Load word from memory"},
    %EVM.Instruction.Metadata{id: 0x52, sym: :mstore, d: 2, a: 0, description: "Save word to memory."},
    %EVM.Instruction.Metadata{id: 0x53, sym: :mstore8, d: 2, a: 0, description: "Save byte to memory."},
    %EVM.Instruction.Metadata{id: 0x54, sym: :sload, d: 1, a: 1, description: "Load word from storage"},
    %EVM.Instruction.Metadata{id: 0x55, sym: :sstore, d: 2, a: 0, description: "Save word to storage"},
    %EVM.Instruction.Metadata{id: 0x56, sym: :jump, d: 1, a: 0, description: "Alter the program counter."},
    %EVM.Instruction.Metadata{id: 0x57, sym: :jumpi, d: 2, a: 0, description: "Conditionally alter the program counter."},
    %EVM.Instruction.Metadata{id: 0x58, sym: :pc, d: 0, a: 1, description: "Get the value of the program counter prior to the increment corresponding to this instruction."},
    %EVM.Instruction.Metadata{id: 0x59, sym: :msize, d: 0, a: 1, description: "Get the size of active memory in bytes"},
    %EVM.Instruction.Metadata{id: 0x5a, sym: :gas, d: 0, a: 1, description: "Get the amount of available gas, including the corresponding reduction for the cost of this instruction."},
    %EVM.Instruction.Metadata{id: 0x5b, sym: :jumpdest, d: 0, a: 0, description: "Mark a valid destination for jumps."},
    %EVM.Instruction.Metadata{id: 0x60, sym: :push1, fun: :push_n, args: [1], d: 0, a: 1, description: "Place 1-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x61, sym: :push2, fun: :push_n, args: [2], d: 0, a: 1, description: "Place 2-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x62, sym: :push3, fun: :push_n, args: [3], d: 0, a: 1, description: "Place 3-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x63, sym: :push4, fun: :push_n, args: [4], d: 0, a: 1, description: "Place 4-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x64, sym: :push5, fun: :push_n, args: [5], d: 0, a: 1, description: "Place 5-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x65, sym: :push6, fun: :push_n, args: [6], d: 0, a: 1, description: "Place 6-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x66, sym: :push7, fun: :push_n, args: [7], d: 0, a: 1, description: "Place 7-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x67, sym: :push8, fun: :push_n, args: [8], d: 0, a: 1, description: "Place 8-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x68, sym: :push9, fun: :push_n, args: [9], d: 0, a: 1, description: "Place 9-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x69, sym: :push10, fun: :push_n, args: [10], d: 0, a: 1, description: "Place 10-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6a, sym: :push11, fun: :push_n, args: [11], d: 0, a: 1, description: "Place 11-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6b, sym: :push12, fun: :push_n, args: [12], d: 0, a: 1, description: "Place 12-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6c, sym: :push13, fun: :push_n, args: [13], d: 0, a: 1, description: "Place 13-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6d, sym: :push14, fun: :push_n, args: [14], d: 0, a: 1, description: "Place 14-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6e, sym: :push15, fun: :push_n, args: [15], d: 0, a: 1, description: "Place 15-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x6f, sym: :push16, fun: :push_n, args: [16], d: 0, a: 1, description: "Place 16-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x70, sym: :push17, fun: :push_n, args: [17], d: 0, a: 1, description: "Place 17-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x71, sym: :push18, fun: :push_n, args: [18], d: 0, a: 1, description: "Place 18-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x72, sym: :push19, fun: :push_n, args: [19], d: 0, a: 1, description: "Place 19-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x73, sym: :push20, fun: :push_n, args: [20], d: 0, a: 1, description: "Place 20-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x74, sym: :push21, fun: :push_n, args: [21], d: 0, a: 1, description: "Place 21-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x75, sym: :push22, fun: :push_n, args: [22], d: 0, a: 1, description: "Place 22-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x76, sym: :push23, fun: :push_n, args: [23], d: 0, a: 1, description: "Place 23-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x77, sym: :push24, fun: :push_n, args: [24], d: 0, a: 1, description: "Place 24-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x78, sym: :push25, fun: :push_n, args: [25], d: 0, a: 1, description: "Place 25-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x79, sym: :push26, fun: :push_n, args: [26], d: 0, a: 1, description: "Place 26-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7a, sym: :push27, fun: :push_n, args: [27], d: 0, a: 1, description: "Place 27-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7b, sym: :push28, fun: :push_n, args: [28], d: 0, a: 1, description: "Place 28-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7c, sym: :push29, fun: :push_n, args: [29], d: 0, a: 1, description: "Place 29-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7d, sym: :push30, fun: :push_n, args: [30], d: 0, a: 1, description: "Place 30-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7e, sym: :push31, fun: :push_n, args: [31], d: 0, a: 1, description: "Place 31-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x7f, sym: :push32, fun: :push_n, args: [32], d: 0, a: 1, description: "Place 32-byte item on stack"},
    %EVM.Instruction.Metadata{id: 0x80, sym: :dup1, d: 1, a: 2, description: "Duplicate 1st stack item."},
    %EVM.Instruction.Metadata{id: 0x81, sym: :dup2, d: 1, a: 2, description: "Duplicate 2nd stack item."},
    %EVM.Instruction.Metadata{id: 0x82, sym: :dup3, d: 1, a: 2, description: "Duplicate 3rd stack item."},
    %EVM.Instruction.Metadata{id: 0x83, sym: :dup4, d: 1, a: 2, description: "Duplicate 4th stack item."},
    %EVM.Instruction.Metadata{id: 0x84, sym: :dup5, d: 1, a: 2, description: "Duplicate 5th stack item."},
    %EVM.Instruction.Metadata{id: 0x85, sym: :dup6, d: 1, a: 2, description: "Duplicate 6th stack item."},
    %EVM.Instruction.Metadata{id: 0x86, sym: :dup7, d: 1, a: 2, description: "Duplicate 7th stack item."},
    %EVM.Instruction.Metadata{id: 0x87, sym: :dup8, d: 1, a: 2, description: "Duplicate 8th stack item."},
    %EVM.Instruction.Metadata{id: 0x88, sym: :dup9, d: 1, a: 2, description: "Duplicate 9th stack item."},
    %EVM.Instruction.Metadata{id: 0x89, sym: :dup10, d: 1, a: 2, description: "Duplicate 10th stack item."},
    %EVM.Instruction.Metadata{id: 0x8a, sym: :dup11, d: 1, a: 2, description: "Duplicate 11th stack item."},
    %EVM.Instruction.Metadata{id: 0x8b, sym: :dup12, d: 1, a: 2, description: "Duplicate 12th stack item."},
    %EVM.Instruction.Metadata{id: 0x8c, sym: :dup13, d: 1, a: 2, description: "Duplicate 13th stack item."},
    %EVM.Instruction.Metadata{id: 0x8d, sym: :dup14, d: 1, a: 2, description: "Duplicate 14th stack item."},
    %EVM.Instruction.Metadata{id: 0x8e, sym: :dup15, d: 1, a: 2, description: "Duplicate 15th stack item."},
    %EVM.Instruction.Metadata{id: 0x8f, sym: :dup16, d: 1, a: 2, description: "Duplicate 16th stack item."},
    %EVM.Instruction.Metadata{id: 0x90, sym: :swap1, d: 2, a: 2, description: "Exchange 1st and 2nd stack items."},
    %EVM.Instruction.Metadata{id: 0x91, sym: :swap2, d: 2, a: 2, description: "Exchange 2nd and 3rd stack items."},
    %EVM.Instruction.Metadata{id: 0x92, sym: :swap3, d: 2, a: 2, description: "Exchange 3rd and 4th stack items."},
    %EVM.Instruction.Metadata{id: 0x93, sym: :swap4, d: 2, a: 2, description: "Exchange 4th and 5th stack items."},
    %EVM.Instruction.Metadata{id: 0x94, sym: :swap5, d: 2, a: 2, description: "Exchange 5th and 6th stack items."},
    %EVM.Instruction.Metadata{id: 0x95, sym: :swap6, d: 2, a: 2, description: "Exchange 6th and 7th stack items."},
    %EVM.Instruction.Metadata{id: 0x96, sym: :swap7, d: 2, a: 2, description: "Exchange 7th and 8th stack items."},
    %EVM.Instruction.Metadata{id: 0x97, sym: :swap8, d: 2, a: 2, description: "Exchange 8th and 9th stack items."},
    %EVM.Instruction.Metadata{id: 0x98, sym: :swap9, d: 2, a: 2, description: "Exchange 9th and 10th stack items."},
    %EVM.Instruction.Metadata{id: 0x99, sym: :swap10, d: 2, a: 2, description: "Exchange 10th and 11th stack items."},
    %EVM.Instruction.Metadata{id: 0x9a, sym: :swap11, d: 2, a: 2, description: "Exchange 11th and 12th stack items."},
    %EVM.Instruction.Metadata{id: 0x9b, sym: :swap12, d: 2, a: 2, description: "Exchange 12th and 13th stack items."},
    %EVM.Instruction.Metadata{id: 0x9c, sym: :swap13, d: 2, a: 2, description: "Exchange 13th and 14th stack items."},
    %EVM.Instruction.Metadata{id: 0x9d, sym: :swap14, d: 2, a: 2, description: "Exchange 14th and 15th stack items."},
    %EVM.Instruction.Metadata{id: 0x9e, sym: :swap15, d: 2, a: 2, description: "Exchange 15th and 16th stack items."},
    %EVM.Instruction.Metadata{id: 0x9f, sym: :swap16, d: 2, a: 2, description: "Exchange 16th and 17th stack items."},
    %EVM.Instruction.Metadata{id: 0xa0, sym: :log0, d: 2, a: 0, description: "Append log record with no topics."},
    %EVM.Instruction.Metadata{id: 0xa1, sym: :log1, d: 3, a: 0, description: "Append log record with one topic."},
    %EVM.Instruction.Metadata{id: 0xa2, sym: :log2, d: 4, a: 0, description: "Append log record with two topics."},
    %EVM.Instruction.Metadata{id: 0xa3, sym: :log3, d: 5, a: 0, description: "Append log record with three topics."},
    %EVM.Instruction.Metadata{id: 0xa4, sym: :log4, d: 6, a: 0, description: "Append log record with four topics."},
    %EVM.Instruction.Metadata{id: 0xf0, sym: :create, d: 3, a: 1, description: "Create a new account with associated code."},
    %EVM.Instruction.Metadata{id: 0xf1, sym: :call, d: 7, a: 1, description: "Message-call into an account.,"},
    %EVM.Instruction.Metadata{id: 0xf2, sym: :callcode, d: 7, a: 1, description: "Message-call into this account with an alternative account’s code.,"},
    %EVM.Instruction.Metadata{id: 0xf3, sym: :return, d: 2, a: 0, description: "Halt execution returning output data,"},
    %EVM.Instruction.Metadata{id: 0xf4, sym: :delegatecall, d: 6, a: 1, description: "Message-call into this account with an alternative account’s code, but persisting the current values for sender and value."},
    %EVM.Instruction.Metadata{id: 0xff, sym: :suicide, d: 1, a: 0, description: "Halt execution and register account for later deletion."},
  ]

  @opcodes_to_metadata (for i <- @instructions, do: {i.id, i}) |> Enum.into(%{})
  @opcodes_to_instructions (for {id, i} <- @opcodes_to_metadata, do: {id, i.sym}) |> Enum.into(%{})
  @instructions_to_opcodes EVM.Helpers.invert(@opcodes_to_instructions)
  @push1  Map.get(@instructions_to_opcodes, :push1)
  @push32 Map.get(@instructions_to_opcodes, :push32)
  @stop Map.get(@instructions_to_opcodes, :stop)

  @doc """
  Returns the current instruction at a given program counter address.

  ## Examples

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 0)
      0x11

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 1)
      0x01

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 2)
      0x02

      iex> EVM.Instruction.get_instruction_at(<<0x11, 0x01, 0x02>>, 3)
      0x00
  """
  @spec get_instruction_at(EVM.MachineCode.t, MachineState.pc) :: opcode
  def get_instruction_at(machine_code, pc) when is_binary(machine_code) and is_integer(pc) do
    if pc < byte_size(machine_code) do
      EVM.Helpers.binary_get(machine_code, pc)
    else
      @stop # Every other position is an implicit STOP code
    end
  end

  @doc """
  Returns the next instruction position given a current position
  and the type of instruction. This is to bypass push operands.

  ## Examples

      iex> EVM.Instruction.next_instr_pos(10, :add)
      11

      iex> EVM.Instruction.next_instr_pos(20, :mul)
      21

      iex> EVM.Instruction.next_instr_pos(10, :push1)
      12

      iex> EVM.Instruction.next_instr_pos(10, :push32)
      43
  """
  @spec next_instr_pos(MachineState.pc, instruction) :: MachineState.pc
  def next_instr_pos(pos, instr) do
    encoded_instruction = instr |> encode

    pos + case encoded_instruction do
      i when i in @push1..@push32 ->
        2 + encoded_instruction - @push1
      _ -> 1
    end
  end

  @doc """
  Returns the given instruction for a given opcode.

  ## Examples

      iex> EVM.Instruction.decode(0x00)
      :stop

      iex> EVM.Instruction.decode(0x01)
      :add

      iex> EVM.Instruction.decode(0x02)
      :mul

      iex> EVM.Instruction.decode(0xffff)
      nil
  """
  @spec decode(opcode) :: instruction | nil
  def decode(opcode) when is_integer(opcode) do
    Map.get(@opcodes_to_instructions, opcode)
  end

  @doc """
  Returns the given opcode for an instruction.

  ## Examples

      iex> EVM.Instruction.encode(:stop)
      0x00

      iex> EVM.Instruction.encode(:add)
      0x01

      iex> EVM.Instruction.encode(:mul)
      0x02

      iex> EVM.Instruction.encode(:salmon)
      nil
  """
  @spec encode(instruction) :: opcode | nil
  def encode(instruction) when is_atom(instruction) do
    Map.get(@instructions_to_opcodes, instruction)
  end

  @doc """
  Returns metadata about a given instruction or opcode, or nil.

  ## Examples

      iex> EVM.Instruction.metadata(:stop)
      %EVM.Instruction.Metadata{id: 0x00, sym: :stop, d: 0, a: 0, description: "Halts execution"}

      iex> EVM.Instruction.metadata(0x00)
      %EVM.Instruction.Metadata{id: 0x00, sym: :stop, d: 0, a: 0, description: "Halts execution"}

      iex> EVM.Instruction.metadata(:add)
      %EVM.Instruction.Metadata{id: 0x01, sym: :add, d: 2, a: 1, description: "Addition operation"}

      iex> EVM.Instruction.metadata(:push1)
      %EVM.Instruction.Metadata{id: 0x60, sym: :push1, fun: :push_n, args: [1], d: 0, a: 1, description: "Place 1-byte item on stack"}

      iex> EVM.Instruction.metadata(0xfe)
      nil

      iex> EVM.Instruction.metadata(nil)
      nil
  """
  @spec metadata(instruction | opcode) :: EVM.Instruction.Metadata.t | nil
  def metadata(nil), do: nil
  def metadata(instruction) when is_atom(instruction) do
    instruction |> encode |> metadata
  end

  def metadata(opcode) when is_integer(opcode) do
    Map.get(@opcodes_to_metadata, opcode)
  end

  @doc """
  Executes a single instruction. This simply does the effects of the instruction itself,
  ignoring the rest of the actions of an instruction cycle. This will effect, for instance,
  the stack, but will not effect the gas, etc.

  ## Examples

      # TODO: How to handle trie state in tests?

      # Add
      iex> EVM.Instruction.run_instruction(:add, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Push
      iex> EVM.Instruction.run_instruction(:push1, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<00, 01>>})
      {%{}, %EVM.MachineState{stack: [1, 1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<00, 01>>}}

      # nil
      iex> EVM.Instruction.run_instruction(:stop, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Unimplemented
      iex> EVM.Instruction.run_instruction(:log0, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec run_instruction(instruction, EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
  def run_instruction(instruction, state, machine_state, sub_state, exec_env) do
    # TODO: Make better / break into smaller sections
    instruction_metadata = metadata(instruction)
    dw = instruction_metadata.d

    {args, stack} = EVM.Stack.pop_n(machine_state.stack, dw)
    updated_machine_state = %{machine_state| stack: stack}

    vm_map = %{
      stack: stack,
      state: state,
      machine_state: updated_machine_state,
      sub_state: sub_state,
      exec_env: exec_env
    }
    fun = instruction_metadata.fun || instruction
    full_args = instruction_metadata.args ++ [args, vm_map]
    op_result = apply(EVM.Instruction.Impl, fun, full_args)

    op_result |> merge_state(instruction, state, updated_machine_state, sub_state, exec_env)
  end

  @doc """
  Merges the state from an opcode with the current environment

  ## Examples

      iex> EVM.Instruction.merge_state(:noop, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(:unimplemented, :blarg, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(%{stack: [1, 2, 3]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(%{machine_state: %EVM.MachineState{stack: [1, 2, 3]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(%{machine_state: %EVM.MachineState{}, sub_state: %EVM.SubState{refund: 5}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{refund: 5}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(%{exec_env: %EVM.ExecEnv{stack_depth: 1}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{stack_depth: 1}}

      iex> EVM.Instruction.merge_state(%{stack: [1, 2, 3], machine_state: %EVM.MachineState{pc: 5, stack: [4, 5]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{pc: 5, stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Instruction.merge_state(%EVM.MachineState{pc: 5, stack: [4, 5]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{pc: 5, stack: [4, 5]}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec merge_state(EVM.Instruction.Impl.op_result, instruction, EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
  def merge_state(:noop, _instruction, state, machine_state, sub_state, exec_env) do
    {state, machine_state, sub_state, exec_env}
  end

  def merge_state(:unimplemented, instruction, state, machine_state, sub_state, exec_env) do
    Logger.debug("Executing (and ignoring) unimplemented instruction: #{instruction}")

    {state, machine_state, sub_state, exec_env}
  end

  def merge_state(updated_machine_state=%EVM.MachineState{}, _instruction, state, _old_machine_state, sub_state, exec_env) do
    {state, updated_machine_state, sub_state, exec_env}
  end

  def merge_state(op_result=%{}, _instruction, state, machine_state, sub_state, exec_env) do
    next_state = op_result[:state] || state

    # For machine state, we can update it by setting machine_state, or stack, or both.
    base_machine_state = op_result[:machine_state] || machine_state
    next_machine_state = if op_result[:stack], do: %{base_machine_state | stack: op_result[:stack]}, else: base_machine_state

    next_sub_state = op_result[:sub_state] || sub_state
    next_exec_env = op_result[:exec_env] || exec_env

    {
      next_state,
      next_machine_state,
      next_sub_state,
      next_exec_env
    }
  end

end