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
    optional(:state) => Trie.t,
    optional(:stack) => Stack.t,
    optional(:machine_state) => MachineState.t,
    optional(:sub_state) => SubState.t,
    optional(:exec_env) => ExecEnv.t
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
  @stop Map.get(@operations_to_opcodes, :stop)

  @doc """
  Returns the current operation at a given program counter address.

  ## Examples

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 0)
      0x11

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 1)
      0x01

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 2)
      0x02

      iex> EVM.Operation.get_operation_at(<<0x11, 0x01, 0x02>>, 3)
      0x00
  """
  @spec get_operation_at(EVM.MachineCode.t, MachineState.pc) :: opcode
  def get_operation_at(machine_code, pc) when is_binary(machine_code) and is_integer(pc) do
    if pc < byte_size(machine_code) do
      EVM.Helpers.binary_get(machine_code, pc)
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
  @spec next_instr_pos(MachineState.pc, operation) :: MachineState.pc
  def next_instr_pos(pos, instr) do
    encoded_operation = instr |> encode

    pos + case encoded_operation do
      i when i in @push1..@push32 ->
        2 + encoded_operation - @push1
      _ -> 1
    end
  end

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
      %EVM.Operation.Metadata{id: 0x60, sym: :push1, fun: :push_n, args: [1], input_count: 0, output_count: 1, description: "Place 1-byte item on stack", group: :push}

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
      iex> EVM.Operation.run_operation(:add, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Push
      iex> EVM.Operation.run_operation(:push1, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<00, 01>>})
      {%{}, %EVM.MachineState{stack: [1, 1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: <<00, 01>>}}

      # nil
      iex> EVM.Operation.run_operation(:stop, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      # Unimplemented
      iex> EVM.Operation.run_operation(:log0, %{}, %EVM.MachineState{stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: []}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec run_operation(operation, EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
  def run_operation(operation, state, machine_state, sub_state, exec_env) do
    {args, updated_machine_state} = operation_args(operation, state, machine_state, sub_state, exec_env)

    apply_to_group_module(operation, args)
      |> normalize_op_result(updated_machine_state.stack)
      |> merge_state(
        operation,
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
      %{stack: [2, 1]}

  """
  @spec normalize_op_result(EVM.val | list(EVM.val) | Operation.op_result, EVM.stack) :: Operation.op_result
  def normalize_op_result(op_result, updated_stack) do
    cond do
      is_integer(op_result) ->
        op_result = op_result
          |> Helpers.wrap_int
          |> Helpers.encode_signed

        %{stack: Stack.push(updated_stack, op_result)}
      is_list(op_result) ->
        %{
          stack: Enum.reduce(op_result, updated_stack, &Stack.push(&2, &1))
        }
      true ->
        op_result
    end
  end

  defp operation_args(operation, state, machine_state, sub_state, exec_env) do
    %EVM.Operation.Metadata{
      input_count: input_count,
      args: metadata_args,
    } = metadata(operation)

    {stack_args, updated_machine_state} = EVM.MachineState.pop_n(machine_state, input_count)

    vm_map = %{
      stack: updated_machine_state.stack,
      state: state,
      machine_state: updated_machine_state,
      sub_state: sub_state,
      exec_env: exec_env
    }
    args = metadata_args ++ [stack_args, vm_map]
    {args, updated_machine_state}
  end

  @doc """
  Merges the state from an opcode with the current environment

  ## Examples

      iex> EVM.Operation.merge_state(:noop, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(:unimplemented, :blarg, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{stack: [1, 2, 3]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{machine_state: %EVM.MachineState{stack: [1, 2, 3]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{machine_state: %EVM.MachineState{}, sub_state: %EVM.SubState{refund: 5}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{refund: 5}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%{exec_env: %EVM.ExecEnv{stack_depth: 1}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{stack_depth: 1}}

      iex> EVM.Operation.merge_state(%{stack: [1, 2, 3], machine_state: %EVM.MachineState{pc: 5, stack: [4, 5]}}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{pc: 5, stack: [1, 2, 3]}, %EVM.SubState{}, %EVM.ExecEnv{}}

      iex> EVM.Operation.merge_state(%EVM.MachineState{pc: 5, stack: [4, 5]}, :add, %{}, %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{})
      {%{}, %EVM.MachineState{pc: 5, stack: [4, 5]}, %EVM.SubState{}, %EVM.ExecEnv{}}
  """
  @spec merge_state(EVM.Operation.Impl.op_result, operation, EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
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
