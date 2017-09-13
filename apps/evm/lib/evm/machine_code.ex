defmodule EVM.MachineCode do
  @moduledoc """
  Functions for helping read a contract's machine code.
  """
  alias EVM.Operation
  alias EVM.MachineState
  alias EVM.ExecEnv

  @type t :: binary()

  @doc """
  Returns the current instruction being executed. In the
  Yellow Paper, this is often referred to as `w`, and is
  defined in Eq.(125) and again in Eq.(221).


  ## Examples

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 0}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x15

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 1}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x11

      iex> EVM.MachineCode.current_instruction(%EVM.MachineState{pc: 2}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      0x12
  """
  @spec current_instruction(MachineState.t, ExecEnv.t) :: Operation.opcode
  def current_instruction(machine_state, exec_env) do
    Operation.get_operation_at(exec_env.machine_code, machine_state.pc)
  end

  @doc """
  Returns true if the given new pc is a valid jump
  destination for the machine code, false otherwise.

  TODO: Memoize

  ## Examples

      iex> EVM.MachineCode.valid_jump_dest?(0, EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      false

      iex> EVM.MachineCode.valid_jump_dest?(4, EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      true

      iex> EVM.MachineCode.valid_jump_dest?(6, EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      false

      iex> EVM.MachineCode.valid_jump_dest?(7, EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      true

      iex> EVM.MachineCode.valid_jump_dest?(100, EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      false
  """
  @spec valid_jump_dest?(MachineState.pc, t) :: boolean()
  def valid_jump_dest?(pc, machine_code) do
    # TODO: This should be sorted for quick lookup
    Enum.member?(machine_code |> valid_jump_destinations, pc)
  end

  @doc """
  Returns the legal jump locations in the given machine code.

  TODO: Memoize

  ## Example

      iex> EVM.MachineCode.valid_jump_destinations(EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      [4, 7]
  """
  @spec valid_jump_destinations(t) :: [MachineState.pc]
  def valid_jump_destinations(machine_code) do
    do_valid_jump_destinations(machine_code, 0)
  end

  # Returns the valid jump destinations by scanning through
  # entire set of machine code
  defp do_valid_jump_destinations(machine_code, pos) do
    instruction = Operation.get_operation_at(machine_code, pos) |> Operation.decode
    next_pos = Operation.next_instr_pos(pos, instruction)

    cond do
      pos >= byte_size(machine_code) -> []
      instruction == :jumpdest ->
        [pos | do_valid_jump_destinations(machine_code, next_pos)]
      true -> do_valid_jump_destinations(machine_code, next_pos)
    end
  end

  @doc """
  Builds machine code for a given set of instructions and data.

  ## Examples

      iex> EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :return])
      <<0x60, 0x03, 0x60, 0x05, 0x01, 0xf3>>

      iex> EVM.MachineCode.compile([])
      <<>>
  """
  @spec compile([atom() | integer()]) :: binary()
  def compile(code) do
    for n <- code do
      case n do
        x when is_atom(x) -> EVM.Operation.encode(n)
        x when is_integer(x) -> x
      end
    end |> :binary.list_to_bin()
  end

  @doc """
  Decompiles machine code.

  ## Examples

      iex> EVM.MachineCode.decompile(<<0x60, 0x03, 0x60, 0x05, 0x01, 0xf3>>)
      [:push1, 3, :push1, 5, :add, :return]

      iex> EVM.MachineCode.decompile(<<97, 0, 4, 128, 97, 0, 14, 96, 0, 57, 97, 0, 18, 86, 96, 0, 53, 255, 91, 96, 0, 243>>)
      [:push2, 0, 4, :dup1, :push2, 0, 14, :push1, 0, :codecopy, :push2, 0, 18, :jump, :push1, 0, :calldataload, :suicide, :jumpdest, :push1, 0, :return]

      iex> EVM.MachineCode.decompile(<<>>)
      []
  """
  @spec decompile(binary()) :: [atom() | integer()]
  def decompile(<<>>), do: []
  def decompile(<<opcode::8, rest::binary()>>) do
    metadata = EVM.Operation.metadata(opcode)

    case metadata.machine_code_offset do
      nil ->
        [metadata.sym | decompile(rest)]
      n ->
        <<data::binary - size(n), non_data_rest::binary()>> = rest
        [metadata.sym | :binary.bin_to_list(data)] ++ decompile(non_data_rest)
    end
  end

end
