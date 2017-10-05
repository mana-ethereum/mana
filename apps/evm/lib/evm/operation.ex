defmodule EVM.Operation do
  @moduledoc """
  Code to handle encoding and decoding
  operations from opcodes.
  """

  alias MathHelper
  alias EVM.Helpers
  alias EVM.ExecEnv
  alias EVM.MachineState
  alias EVM.Stack
  alias EVM.SubState
  alias EVM.Operation.Metadata.StopAndArithmetic, as: StopAndArithmeticMetadata
  alias EVM.Operation.Metadata.ComparisonAndBitwiseLogic, as: ComparisonAndBitwiseLogicMetadata
  alias EVM.Operation.Metadata.SHA3, as: SHA3Metadata
  alias EVM.Operation.Metadata.EnvironmentalInformation, as: EnvironmentalInformationMetadata
  alias EVM.Operation.Metadata.BlockInformation, as: BlockInformationMetadata
  alias EVM.Operation.Metadata.StackMemoryStorageAndFlow, as: StackMemoryStorageAndFlowMetadata
  alias EVM.Operation.Metadata.Push, as: PushMetadata
  alias EVM.Operation.Metadata.Duplication, as: DuplicationMetadata
  alias EVM.Operation.Metadata.Exchange, as: ExchangeMetadata
  alias EVM.Operation.Metadata.Logging, as: LoggingMetadata
  alias EVM.Operation.Metadata.System, as: SystemMetadata


  use Bitwise

  require Logger

  @type operation :: atom()
  @type opcode :: byte()
  @type stack_args :: [EVM.val]
  @type vm_map :: %{
    optional(:state) => EVM.world_state,
    optional(:stack) => Stack.t,
    optional(:machine_state) => MachineState.t,
    optional(:sub_state) => SubState.t,
    optional(:exec_env) => ExecEnv.t,
    optional(:block_interface) => EVM.BlockInterface.t,
    optional(:contract_interface) => EVM.ContractInterface.t,
    optional(:account_interface) => EVM.AccountInterface.t
  }
  @type noop :: :noop


  @operations (
    StopAndArithmeticMetadata.operations() ++
    ComparisonAndBitwiseLogicMetadata.operations() ++
    SHA3Metadata.operations() ++
    EnvironmentalInformationMetadata.operations() ++
    BlockInformationMetadata.operations() ++
    StackMemoryStorageAndFlowMetadata.operations() ++
    PushMetadata.operations() ++
    DuplicationMetadata.operations() ++
    ExchangeMetadata.operations() ++
    LoggingMetadata.operations() ++
    SystemMetadata.operations()
  )

  @opcodes_to_metadata (for i <- @operations, do: {i.id, i}) |> Enum.into(%{})
  @opcodes_to_operations (for {id, i} <- @opcodes_to_metadata, do: {id, i.sym}) |> Enum.into(%{})
  @operations_to_opcodes EVM.Helpers.invert(@opcodes_to_operations)
  @push1  Map.get(@operations_to_opcodes, :push1)
  @push32 Map.get(@operations_to_opcodes, :push32)
  @push_operations @push1..@push32
  @jump_operations [:jump, :jumpi]
  @stop Map.get(@operations_to_opcodes, :stop)

  def jump_operations(), do: @jump_operations

  @doc """
  Returns the current operation at a given program counter address.

  ## Examples

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 0)
      17

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 1)
      1

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 2)
      2

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 3)
      0
  """
  @spec get_operation_at(EVM.MachineCode.t, MachineState.program_counter) :: opcode
  def get_operation_at(machine_code, program_counter) when is_binary(machine_code) and is_integer(program_counter) do
    if program_counter < byte_size(machine_code) do
      :binary.at(machine_code, program_counter)
    else
      @stop # Every other position is an implicit STOP code
    end
  end

  @doc """
  Returns the next operation position given a current position
  and the type of operation. This is to bypass push operands.

  ## Examples

      iex> EVM.Operation.next_instr_pos(10, :add)
      11

      iex> EVM.Operation.next_instr_pos(20, :mul)
      21

      iex> EVM.Operation.next_instr_pos(10, :push1)
      12

      iex> EVM.Operation.next_instr_pos(10, :push32)
      43
  """
  @spec next_instr_pos(MachineState.program_counter, operation) :: MachineState.program_counter
  def next_instr_pos(pos, instr) do
    encoded_operation = instr |> encode

    pos + push_length(encoded_operation) + 1
  end

  defp push_length(operation) when operation in @push_operations, do:
    operation - (@push1 - 1)
  defp push_length(_operation), do: 0

  @doc """
  Returns the given operation for a given opcode.

  ## Examples

      iex> EVM.Operation.decode(0x00)
      :stop

      iex> EVM.Operation.decode(0x01)
      :add

      iex> EVM.Operation.decode(0x02)
      :mul

      iex> EVM.Operation.decode(0xffff)
      nil
  """
  @spec decode(opcode) :: operation | nil
  def decode(opcode) when is_integer(opcode) do
    Map.get(@opcodes_to_operations, opcode)
  end

  @doc """
  Returns the given opcode for an operation.

  ## Examples

      iex> EVM.Operation.encode(:stop)
      0x00

      iex> EVM.Operation.encode(:add)
      0x01

      iex> EVM.Operation.encode(:mul)
      0x02

      iex> EVM.Operation.encode(:salmon)
      nil
  """
  @spec encode(operation) :: opcode | nil
  def encode(operation) when is_atom(operation) do
    Map.get(@operations_to_opcodes, operation)
  end

  @doc """
  Returns metadata about a given operation or opcode, or nil.

  ## Examples

      iex> EVM.Operation.metadata(:stop)
      %EVM.Operation.Metadata{id: 0x00, sym: :stop, input_count: 0, output_count: 0, description: "Halts execution", group: :stop_and_arithmetic}

      iex> EVM.Operation.metadata(0x00)
      %EVM.Operation.Metadata{id: 0x00, sym: :stop, input_count: 0, output_count: 0, description: "Halts execution", group: :stop_and_arithmetic}

      iex> EVM.Operation.metadata(:add)
      %EVM.Operation.Metadata{id: 0x01, sym: :add, input_count: 2, output_count: 1, description: "Addition operation", group: :stop_and_arithmetic}

      iex> EVM.Operation.metadata(:push1)
      %EVM.Operation.Metadata{id: 0x60, sym: :push1, fun: :push_n, args: [1], input_count: 0, output_count: 1, description: "Place 1-byte item on stack", group: :push, machine_code_offset: 1}

      iex> EVM.Operation.metadata(0xfe)
      nil

      iex> EVM.Operation.metadata(nil)
      nil
  """
  @spec metadata(operation | opcode) :: EVM.Operation.Metadata.t | nil
  def metadata(nil), do: nil
  def metadata(operation) when is_atom(operation) do
    operation |> encode |> metadata
  end

  def metadata(opcode) when is_integer(opcode) do
    Map.get(@opcodes_to_metadata, opcode)
  end

  @doc """
  Executes a single operation. This simply does the effects of the operation itself,
  ignoring the rest of the actions of an operation cycle. This will effect, for instance,
  the stack, but will not effect the gas, etc.

  ## Examples

      # TODO: How to handle trie state in tests?

      # Add
      iex> EVM.Operation.run_operation(EVM.Operation.metadata(:add), %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Push
      iex> EVM.Operation.run_operation(EVM.Operation.metadata(:push1), %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<00, 01>>})
      {%{}, %EVM.MachineState{stack: [1, 1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<0, 1>>}}

      # nil
      iex> EVM.Operation.run_operation(EVM.Operation.metadata(:stop), %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Unimplemented
      iex> EVM.Operation.run_operation(EVM.Operation.metadata(:log0), %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec run_operation(EVM.Operation.Metadata.t, EVM.world_state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.world_state, MachineState.t, SubState.t, ExecEnv.t}
  def run_operation(operation, state, machine_state, sub_state, exec_env) do
    {args, updated_machine_state} = operation_args(operation, state, machine_state, sub_state, exec_env)

    apply_to_group_module(operation.sym, args)
      |> normalize_op_result(updated_machine_state.stack)
      |> merge_state(
        operation.sym,
        state,
        updated_machine_state,
        sub_state,
        exec_env
      )
  end

  @spec apply_to_group_module(operation, list(EVM.val)) :: Operation.op_result
  defp apply_to_group_module(operation, args) do
    %EVM.Operation.Metadata{fun: fun, group: group} = metadata(operation)
    method = fun || operation

    apply(group_to_module(group), method, args)
  end

  @spec group_to_module(atom()) :: Operation.op_result
  defp group_to_module(group), do:
    "Elixir.EVM.Operation." <>
      Macro.camelize(Atom.to_string(group))
        |> String.to_atom


  @doc """
  Normalizes op_results. If the result is an integer it encodes it
  and pushes it onto the stack. If it's a list pushes each element onto
  the stack. Otherwise it returns what's given to it.

  ## Examples
  #
      iex> EVM.Operation.normalize_op_result(1, [])
      %{stack: [1]}
      iex> EVM.Operation.normalize_op_result([1,2], [])
      %{stack: [1, 2]}

  """
  @spec normalize_op_result(EVM.val | list(EVM.val) | Operation.op_result, EVM.stack) :: Operation.op_result
  def normalize_op_result(op_result, updated_stack) do
    if is_integer(op_result) || is_list(op_result) || is_binary(op_result) do
      %{stack: Stack.push(updated_stack, Helpers.encode_val(op_result))}
    else
      op_result
    end
  end

  @doc """
  Returns an operation's inputs

  ## Examples
  #
      iex> EVM.Operation.inputs(EVM.Operation.metadata(:add), %{stack: [1, 2, 3]})
      [1, 2]

  """
  @spec inputs(Stack.t, Operation.t) :: list(EVM.val)
  def inputs(_stack, nil), do: []
  def inputs(operation, machine_state) do
    Stack.peek_n(machine_state.stack, operation.input_count)
  end

  defp operation_args(operation, state, machine_state, sub_state, exec_env) do
    {stack_args, updated_machine_state} = EVM.MachineState.pop_n(machine_state, operation.input_count)

    vm_map = %{
      stack: updated_machine_state.stack,
      state: state,
      machine_state: updated_machine_state,
      sub_state: sub_state,
      exec_env: exec_env
    }
    args = operation.args ++ [stack_args, vm_map]
    {args, updated_machine_state}
  end

  @doc """
  Merges the state from an opcode with the current environment

  ## Examples

      iex> EVM.Operation.merge_state(:noop, EVM.Operation.metadata(:add), %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(:unimplemented, EVM.Operation.metadata(:blarg), %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{stack: [1, 2, 3]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{machine_state: %EVM.MachineState{stack: [1, 2, 3]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{machine_state: %EVM.MachineState{}, sub_state: %EVM.SubState{refund: 5}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{refund: 5}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{exec_env: %EVM.ExecEnv{stack_depth: 1}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{stack_depth: 1}}

      iex> EVM.Operation.merge_state(%{stack: [1, 2, 3], machine_state: %EVM.MachineState{program_counter: 5, stack: [4, 5]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{program_counter: 5, stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%EVM.MachineState{program_counter: 5, stack: [4, 5]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{program_counter: 5, stack: [4, 5]}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec merge_state(EVM.Operation.Impl.op_result, operation, EVM.world_state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.world_state, MachineState.t, SubState.t, ExecEnv.t}
  def merge_state(:noop, _operation, state, machine_state, sub_state, exec_env) do
    {state, machine_state, sub_state, exec_env}
  end

  def merge_state(:unimplemented, operation, state, machine_state, sub_state, exec_env) do
    Logger.debug("Executing (and ignoring) unimplemented operation: #{operation}")

    {state, machine_state, sub_state, exec_env}
  end

  def merge_state(updated_machine_state=%EVM.MachineState{}, _operation, state, _old_machine_state, sub_state, exec_env) do
    {state, updated_machine_state, sub_state, exec_env}
  end

  def merge_state(op_result=%{}, _operation, state, machine_state, sub_state, exec_env) do
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
