defmodule EVM.Debugger do
  @moduledoc """
  A first-class debugger for the EVM. We are able to set
  breakpoints and walk through code execution.
  """

  alias EVM.Debugger.Breakpoint
  alias EVM.Debugger.Command
  alias EVM.SubState
  alias EVM.ExecEnv
  alias EVM.MachineState

  @commands [
    %Command{
      command: :next,
      name: "next",
      shortcut: "n",
      description: "Run this operation and break on next operation."
    },
    %Command{
      command: :continue,
      name: "continue",
      shortcut: "c",
      description: "Stop debugging and continue operation of program."
    },
    %Command{
      command: :debug,
      name: "debug",
      shortcut: "d",
      description: "Show detailed debug environment information."
    },
    %Command{
      command: :stack,
      name: "stack",
      shortcut: "s",
      description: "Show current program stack."
    },
    %Command{command: :pc, name: "pc", shortcut: "p", description: "Show current program pc."},
    %Command{command: :help, name: "help", shortcut: "h", description: "Show this help screen."},
    %Command{
      command: :where,
      name: "where",
      shortcut: "w",
      description:
        "Show where pc is in the currently executing code. (optional args: `where [length]`)"
    },
    %Command{
      command: :machine_state,
      name: "machine",
      description: "Prints the current machine state."
    },
    %Command{
      command: :memory,
      name: "memory",
      shortcut: "m",
      description: "Prints the current machine's memory."
    }
  ]

  @current_instruction_start 3
  @current_instruction_length 10
  @chunk_size 10

  @doc """
  Enables the debugger.

  Note: the debugger should only be run when debugging; it may
        seriously degrade performance of the VM during normal
        operations.

  ## Examples

      iex> EVM.Debugger.enable
      :ok
      iex> EVM.Debugger.is_enabled?
      true
      iex> EVM.Debugger.disable
      :ok
      iex> EVM.Debugger.enable
      :ok
      iex> EVM.Debugger.disable
      :ok
  """
  @spec enable() :: :ok
  def enable() do
    Application.put_env(__MODULE__, :enabled, true)

    EVM.Debugger.Breakpoint.init()
  end

  @doc """
  Disables the debugger.

  ## Examples

      iex> EVM.Debugger.disable
      :ok
      iex> EVM.Debugger.enable
      :ok
      iex> EVM.Debugger.disable
      :ok
  """
  @spec disable() :: :ok
  def disable() do
    Application.put_env(__MODULE__, :enabled, false)
  end

  @doc """
  Returns true only if debugging is currently enabled.

  This is set in the application config.

  ## Examples

      iex> Application.put_env(EVM.Debugger, :enabled, true)
      iex> EVM.Debugger.is_enabled?
      true
      iex> Application.put_env(EVM.Debugger, :enabled, false)
      :ok

      iex> Application.put_env(EVM.Debugger, :enabled, false)
      iex> EVM.Debugger.is_enabled?
      false

      iex> EVM.Debugger.is_enabled?
      false
  """
  @spec is_enabled?() :: boolean()
  def is_enabled? do
    Application.get_env(__MODULE__, :enabled, false)
  end

  @doc """
  Sets a new breakpoint based on supplied conditions.

  ## Examples

      iex> id = EVM.Debugger.break_on(address: <<188, 31, 252, 22, 32, 218, 20, 104, 98, 74, 89, 108, 184, 65, 211, 94, 107, 47, 31, 182>>)
      iex> EVM.Debugger.Breakpoint.get_breakpoint(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<188, 31, 252, 22, 32, 218, 20, 104, 98, 74, 89, 108, 184, 65, 211, 94, 107, 47, 31, 182>>], pc: :start}
  """
  @spec break_on(keyword(Breakpoint.conditions())) :: Breakpoint.id()
  def break_on(conditions) do
    Breakpoint.set_breakpoint(%Breakpoint{conditions: conditions, pc: :start})
  end

  @doc """
  Return true if the currently line of code is tripped by
  any previously set breakpoint.

  ## Examples

      iex> EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<25::160>>], pc: :next})
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<25::160>>}
      iex> EVM.Debugger.is_breakpoint?(machine_state, sub_state, exec_env) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<25::160>>], pc: :next}

      iex> EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<25::160>>], enabled: false})
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<26::160>>}
      iex> EVM.Debugger.is_breakpoint?(machine_state, sub_state, exec_env)
      :continue
  """
  @spec is_breakpoint?(MachineState.t(), SubState.t(), EVM.ExecEnv.t()) :: :continue | Breakpoint.t()
  def is_breakpoint?(machine_state, sub_state, exec_env) do
    Enum.find(Breakpoint.get_breakpoints(), :continue, fn breakpoint ->
      Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
    end)
  end

  @doc """
  Breaks execution and begins a REPL to interact with the currently executing code.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<25::160>>], enabled: false})
      iex> breakpoint = EVM.Debugger.Breakpoint.get_breakpoint(id)
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<26::160>>}
      iex> EVM.Debugger.break(breakpoint, machine_state, sub_state, exec_env, ["continue"])
      { %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{address: <<26::160>>} }

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<25::160>>], enabled: false})
      iex> breakpoint = EVM.Debugger.Breakpoint.get_breakpoint(id)
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<26::160>>}
      iex> EVM.Debugger.break(breakpoint, machine_state, sub_state, exec_env, ["zzzzzzz", "continue"])
      { %EVM.MachineState{}, %EVM.SubState{}, %EVM.ExecEnv{address: <<26::160>>} }
  """
  @spec break(Breakpoint.t(), MachineState.t(), SubState.t(), ExecEnv.t(), [String.t()]) ::
          {MachineState.t(), SubState.t(), ExecEnv.t()}
  def break(breakpoint, machine_state, sub_state, exec_env, input_sequence \\ []) do
    Breakpoint.clear_pc_if_one_time_break(breakpoint.id)

    if breakpoint.pc == :start do
      # If we're not next, we're likely a freshly hit breakpoint and should display a helpful prompt
      # to the user.
      IO.puts(
        "\n\n-- Breakpoint ##{breakpoint.id} triggered with conditions #{
          Breakpoint.describe(breakpoint)
        } --"
      )
    end

    IO.puts("")
    print_machine_state(machine_state)
    IO.puts("")
    print_current_instruction(exec_env, machine_state)

    if breakpoint.pc == :start do
      IO.puts("Enter a debug command or type `h` for help.")
      IO.puts("")
    end

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  @spec print_machine_state(MachineState.t()) :: any()
  def print_machine_state(machine_state) do
    IO.puts(
      "gas: #{machine_state.gas} | pc: #{machine_state.program_counter} | memory: #{
        machine_state.memory |> byte_size
      } | words: #{machine_state.active_words} | # stack: #{machine_state.stack |> Enum.count()}"
    )
  end

  @spec print_current_instruction(ExecEnv.t(), MachineState.t(), integer(), integer()) :: any()
  defp print_current_instruction(
         exec_env,
         machine_state,
         start \\ @current_instruction_start,
         len \\ @current_instruction_length
       ) do
    if is_nil(machine_state.program_counter) do
      IO.puts("??? invalid pc ???")
      IO.puts("")
    else
      machine_code = EVM.MachineCode.decompile(exec_env.machine_code)

      index_width =
        if machine_code == [],
          do: 0,
          else: machine_code |> Enum.count() |> :math.log10() |> :math.ceil() |> round

      machine_code
      |> Enum.with_index()
      |> Enum.slice(max(machine_state.program_counter - start, 0), len)
      |> Enum.each(fn {instruction, index} ->
        pointer = if machine_state.program_counter == index, do: "----> ", else: "      "
        instruction_str = instruction |> to_string
        index_str = "[#{index |> to_string |> String.pad_leading(index_width)}] "

        IO.puts("#{pointer}#{index_str}#{instruction_str}")
      end)

      IO.puts("")
    end
  end

  @spec prompt(Breakpoint.t(), MachineState.t(), SubState.t(), ExecEnv.t(), [String.t()]) ::
          {MachineState.t(), SubState.t(), ExecEnv.t()}
  defp prompt(breakpoint, machine_state, sub_state, exec_env, [input | rest]),
    do: handle_input(input, breakpoint, machine_state, sub_state, exec_env, rest)

  defp prompt(breakpoint, machine_state, sub_state, exec_env, []) do
    IO.gets(">> ")
    |> handle_input(breakpoint, machine_state, sub_state, exec_env, [])
  end

  @spec handle_input(String.t(), Breakpoint.t(), MachineState.t(), SubState.t(), ExecEnv.t(), [
          String.t()
        ]) :: {MachineState.t(), SubState.t(), ExecEnv.t()}
  def handle_input(input, breakpoint, machine_state, sub_state, exec_env, input_sequence) do
    case String.split(input |> String.trim(), " ", trim: true) do
      [] ->
        prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)

      [command_string | args] ->
        command =
          Enum.find(@commands, fn command ->
            command.name == command_string or command.shortcut == String.first(command_string)
          end)

        if command do
          handle_prompt(
            command.command,
            args,
            breakpoint,
            machine_state,
            sub_state,
            exec_env,
            input_sequence
          )
        else
          IO.puts("unknown command: `#{command_string}`")

          prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
        end
    end
  end

  # Handle prompt passes the prompt information bac
  @spec handle_prompt(
          atom(),
          [String.t()],
          Breakpoint.t(),
          MachineState.t(),
          SubState.t(),
          ExecEnv.t(),
          [String.t()]
        ) :: {MachineState.t(), SubState.t(), ExecEnv.t()}
  defp handle_prompt(
         command,
         args,
         breakpoint,
         machine_state,
         sub_state,
         exec_env,
         input_sequence
       )

  defp handle_prompt(:help, _args, breakpoint, machine_state, sub_state, exec_env, input_sequence) do
    # TODO: Handle args, make nicer

    IO.puts("")

    IO.puts(
      "The EVM Debugger helps you understand a message or contract call in the EVM. Please choose a command from the following list of options:"
    )

    IO.puts("")

    for command <- @commands do
      [
        command.name,
        if(command.shortcut, do: "(#{command.shortcut})", else: nil),
        "-",
        command.description
      ]
      |> Enum.filter(fn s -> not is_nil(s) end)
      |> Enum.join(" ")
      |> IO.puts()
    end

    IO.puts("")

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(
         :debug,
         _args,
         breakpoint,
         machine_state,
         sub_state,
         exec_env,
         input_sequence
       ) do
    IO.inspect([machine_state, sub_state, exec_env], limit: :infinity)

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(
         :stack,
         _args,
         breakpoint,
         machine_state,
         sub_state,
         exec_env,
         input_sequence
       ) do
    IO.puts("")
    IO.puts("Machine Stack")

    stack_length = machine_state.stack |> Enum.count()
    tail = stack_length - 1

    case machine_state.stack do
      [] ->
        IO.puts("<empty>")

      stack ->
        width =
          machine_state.stack
          |> Enum.map(fn v -> v |> to_string |> String.length() end)
          |> Enum.max()

        for {v, i} <- stack |> Enum.with_index() do
          heading =
            case i do
              0 -> "HEAD ->"
              ^tail -> "TAIL ->"
              _ -> "       "
            end

          IO.puts("#{heading} #{String.pad_leading(to_string(v), width)}")
        end
    end

    IO.puts("")

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(
         :memory,
         _args,
         breakpoint,
         machine_state = %EVM.MachineState{memory: memory},
         sub_state,
         exec_env,
         input_sequence
       ) do
    total_size = byte_size(memory)

    size_width =
      if total_size > 0, do: total_size |> :math.log10() |> :math.ceil() |> round, else: 0

    IO.puts("")
    IO.puts("Memory (#{total_size} #{if total_size == 1, do: "byte", else: "bytes"})")
    IO.puts("")

    for {chunk, n} <-
          Enum.chunk(memory |> String.codepoints(), @chunk_size, @chunk_size, [])
          |> Enum.with_index() do
      offset = n * @chunk_size

      ascii =
        chunk
        |> Enum.map(fn codepoint ->
          if codepoint |> String.to_charlist() |> List.first() |> printable,
            do: codepoint,
            else: "."
        end)
        |> Enum.join()
        |> String.pad_leading(@chunk_size)

      hex =
        chunk
        |> Enum.map(fn codepoint -> Base.encode16(codepoint) end)
        |> Enum.join(" ")
        |> String.pad_leading(@chunk_size * 3, " ")

      IO.puts("[#{String.pad_leading(offset |> to_string, size_width)}] #{hex} #{ascii}")
    end

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(
         :machine_state,
         _args,
         breakpoint,
         machine_state,
         sub_state,
         exec_env,
         input_sequence
       ) do
    print_machine_state(machine_state)

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(:pc, _args, breakpoint, machine_state, sub_state, exec_env, input_sequence) do
    IO.puts("The current program count is: #{machine_state.program_counter}")

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(:where, args, breakpoint, machine_state, sub_state, exec_env, input_sequence) do
    len =
      case Enum.at(args, 0, nil) do
        nil ->
          @current_instruction_length

        str ->
          case Integer.parse(str) do
            {len, ""} -> len
            _els -> @current_instruction_length
          end
      end

    print_current_instruction(exec_env, machine_state, @current_instruction_start, len * 2)

    prompt(breakpoint, machine_state, sub_state, exec_env, input_sequence)
  end

  defp handle_prompt(
         :next,
         _args,
         breakpoint,
         machine_state,
         sub_state,
         exec_env,
         _input_sequence
       ) do
    Breakpoint.set_next(breakpoint.id)

    {machine_state, sub_state, exec_env}
  end

  defp handle_prompt(
         :continue,
         _args,
         _breakpoint,
         machine_state,
         sub_state,
         exec_env,
         _input_sequence
       ) do
    {machine_state, sub_state, exec_env}
  end

  @spec printable(integer()) :: boolean()
  defp printable(x) when x in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789',
    do: true

  defp printable(_), do: false
end
