defmodule EVM.MachineCode do
  @moduledoc """
  Functions for helping read a contract's machine code.
  """
  alias EVM.{ExecEnv, MachineState, Operation}
  alias EVM.Operation.Metadata

  @type t :: binary()

  @doc """
  Returns the current instruction being executed. In the
  Yellow Paper, this is often referred to as `w`, and is
  defined in Eq.(125) and again in Eq.(221).

  ## Examples

      iex> EVM.MachineCode.current_operation(%EVM.MachineState{program_counter: 0}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      %EVM.Operation.Metadata{args: [], description: "Simple not operator.", fun: nil, group: :comparison_and_bitwise_logic, id: 21, input_count: 1, machine_code_offset: 0, output_count: 1, sym: :iszero}

      iex> EVM.MachineCode.current_operation(%EVM.MachineState{program_counter: 1}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      %EVM.Operation.Metadata{args: [], description: "Greater-than comparision.", fun: nil, group: :comparison_and_bitwise_logic, id: 17, input_count: 2, machine_code_offset: 0, output_count: 1, sym: :gt}

      iex> EVM.MachineCode.current_operation(%EVM.MachineState{program_counter: 2}, %EVM.ExecEnv{machine_code: <<0x15::8, 0x11::8, 0x12::8>>})
      %EVM.Operation.Metadata{args: [], description: "Signed less-than comparision.", fun: nil, group: :comparison_and_bitwise_logic, id: 18, input_count: 2, machine_code_offset: 0, output_count: 1, sym: :slt}
  """
  @spec current_operation(MachineState.t(), ExecEnv.t()) :: Metadata.t()
  def current_operation(machine_state, exec_env) do
    exec_env.machine_code
    |> Operation.get_operation_at(machine_state.program_counter)
    |> Operation.metadata()
  end

  @doc """
  Returns the legal jump locations in the given machine code.

  ## Example

      iex> EVM.MachineCode.valid_jump_destinations(EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop]))
      [4, 7]
  """
  @spec valid_jump_destinations(t) :: [MachineState.program_counter()]
  def valid_jump_destinations(machine_code) do
    do_valid_jump_destinations(machine_code, 0)
  end

  # Returns the valid jump destinations by scanning through
  # entire set of machine code
  defp do_valid_jump_destinations(machine_code, pos) do
    operation =
      machine_code
      |> Operation.get_operation_at(pos)
      |> Operation.decode()

    next_pos = Operation.next_instr_pos(pos, operation)

    cond do
      pos >= byte_size(machine_code) ->
        []

      operation == :jumpdest ->
        [pos | do_valid_jump_destinations(machine_code, next_pos)]

      true ->
        do_valid_jump_destinations(machine_code, next_pos)
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
    for n <- code, into: <<>> do
      num =
        case n do
          x when is_atom(x) -> EVM.Operation.encode(n)
          x when is_integer(x) -> x
        end

      :binary.encode_unsigned(num)
    end
  end

  @doc """
  Decompiles machine code.

  ## Options

  * `:strict` (boolean) - if `true`, decompilation will raise an exception when unknown opcodes are encountered. If `false`, an `{:unknown, integer()}` will appear in place of the decoded op. Defaults to `true`.

  ## Examples

      iex> EVM.MachineCode.decompile(<<0x60, 0x03, 0x60, 0x05, 0x01, 0xf3>>)
      [:push1, 3, :push1, 5, :add, :return]

      iex> EVM.MachineCode.decompile(<<97, 0, 4, 128, 97, 0, 14, 96, 0, 57, 97, 0, 18, 86, 96, 0, 53, 255, 91, 96, 0, 243>>)
      [:push2, 0, 4, :dup1, :push2, 0, 14, :push1, 0, :codecopy, :push2, 0, 18, :jump, :push1, 0, :calldataload, :selfdestruct, :jumpdest, :push1, 0, :return]

      iex> EVM.MachineCode.decompile(<<>>)
      []

      iex> EVM.MachineCode.decompile(<<0x68, 0x00, 0x29>>)
      [:push9, 0, 41, 0, 0, 0, 0, 0, 0, 0]

      iex> EVM.MachineCode.decompile(<<0xfe, 0xf3>>, strict: false)
      [:invalid, :return]

      iex> EVM.MachineCode.decompile(<<0xfee, 0xf3>>, strict: false)
      [{:unknown, 238}, :return]
  """
  @type decompile_option :: {:strict, true | false}
  @spec decompile(binary(), [decompile_option]) :: [atom() | integer()]
  def decompile(bytecode, opts \\ []), do: decompile([], bytecode, opts)

  defp decompile(acc, <<>>, _), do: Enum.reverse(acc)

  defp decompile(acc, <<opcode::8, bytecode::binary()>>, opts) do
    {op, rest_of_bytecode} =
      decompile_opcode(opcode, EVM.Operation.metadata(opcode), bytecode, opts)

    decompile(op ++ acc, rest_of_bytecode, opts)
  end

  defp decompile_opcode(opcode, nil, bytecode, opts) do
    if Keyword.get(opts, :strict, true) do
      raise ArgumentError, "unknown opcode 0x#{Integer.to_string(opcode, 16)} encountered"
    else
      {[{:unknown, opcode}], bytecode}
    end
  end

  defp decompile_opcode(_opcode, %{sym: sym, machine_code_offset: args_size}, bytecode, _opts) do
    decompile_instr(sym, args_size, bytecode)
  end

  defp decompile_instr(sym, nil, bytecode), do: {[sym], bytecode}
  defp decompile_instr(sym, 0, bytecode), do: {[sym], bytecode}

  defp decompile_instr(sym, args_size, bytecode) do
    {encoded_argdata, rest_of_bytecode} = consume_instr_args(bytecode, args_size)
    argdata = :binary.bin_to_list(encoded_argdata)
    {Enum.reverse([sym | argdata]), rest_of_bytecode}
  end

  defp consume_instr_args(bytecode, args_size) when args_size > byte_size(bytecode) do
    pad_by_bits = (args_size - byte_size(bytecode)) * 8
    {bytecode <> <<0::size(pad_by_bits)>>, <<>>}
  end

  defp consume_instr_args(bytecode, args_size) do
    <<op_args::binary-size(args_size), rest::binary()>> = bytecode
    {op_args, rest}
  end
end
