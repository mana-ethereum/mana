defmodule EVM.Debugger.Breakpoint do
  @moduledoc """
  Breakpoints allow us to break execution of a given
  contract based on a set of conditions.
  """

  @table __MODULE__

  @type id :: integer()

  @type conditions :: [
          # only triggers when contract executes at given address
          :address
        ]

  @type t :: %__MODULE__{
          id: id | nil,
          enabled: boolean(),
          conditions: conditions | [],
          pc: nil | :start | :next | integer()
        }

  defstruct id: nil,
            enabled: true,
            conditions: [],
            pc: nil

  @doc """
  Initializes the debugger. Must be called prior to getting or checking
  breakpoints.
  """
  @spec init() :: :ok
  def init() do
    case :ets.info(@table) do
      :undefined -> :ets.new(@table, [:ordered_set, :public, :named_table])
      _info -> :table_exists
    end

    :ok
  end

  @doc """
  Adds a global breakpoint condition.

  We can set the following types of breakpoints:
  ...

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<15::160>>]})
      iex> EVM.Debugger.Breakpoint.get_breakpoint(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<15::160>>]}
  """
  @spec set_breakpoint(t) :: id
  def set_breakpoint(breakpoint) do
    id = next_id()
    true = :ets.insert_new(@table, {id, %{breakpoint | id: id}})
    id
  end

  @doc """
  Gets a breakpoint by id. This will raise if no such breakpoint
  is found.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>]})
      iex> EVM.Debugger.Breakpoint.get_breakpoint(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>]}

      iex> EVM.Debugger.Breakpoint.get_breakpoint(999)
      ** (CaseClauseError) no case clause matching: []
  """
  @spec get_breakpoint(id) :: t
  def get_breakpoint(breakpoint_id) do
    case :ets.lookup(@table, breakpoint_id) do
      [{_id, breakpoint}] -> breakpoint
    end
  end

  @doc """
  Returns true if a given breakpoint matches the current execution environment.

  Note: we currently only support address matching.

  ## Examples

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: :next}
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<20::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      true

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: 999}
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<20::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      false

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: 999}
      iex> machine_state = %EVM.MachineState{program_counter: 999}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<20::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      true

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: nil}
      iex> machine_state = %EVM.MachineState{program_counter: 999}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<20::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      false

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], enabled: false, pc: :next}
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<20::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      false

      iex> breakpoint = %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: :next}
      iex> machine_state = %EVM.MachineState{}
      iex> sub_state = %EVM.SubState{}
      iex> exec_env = %EVM.ExecEnv{address: <<21::160>>}
      iex> EVM.Debugger.Breakpoint.matches?(breakpoint, machine_state, sub_state, exec_env)
      false
  """
  @spec matches?(t, EVM.MachineState.t(), EVM.SubState.t(), EVM.ExecEnv.t()) :: boolean()
  def matches?(breakpoint, machine_state, _sub_state, exec_env) do
    breakpoint.enabled and break_on_next_pc?(breakpoint, machine_state.program_counter) and
      Enum.all?(breakpoint.conditions, fn {condition, condition_val} ->
        case condition do
          :address -> exec_env.address == condition_val
        end
      end)
  end

  @doc """
  Describes a breakpoint's trigger conditions.

  ## Examples

      iex> %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: :next} |> EVM.Debugger.Breakpoint.describe
      "contract address 0x0000000000000000000000000000000000000014 (next)"

      iex> %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: :start} |> EVM.Debugger.Breakpoint.describe
      "contract address 0x0000000000000000000000000000000000000014 (start)"

      iex> %EVM.Debugger.Breakpoint{conditions: [address: <<20::160>>], pc: nil} |> EVM.Debugger.Breakpoint.describe
      "contract address 0x0000000000000000000000000000000000000014 (waiting)"

      iex> %EVM.Debugger.Breakpoint{conditions: [], pc: nil} |> EVM.Debugger.Breakpoint.describe
      "(waiting)"
  """
  @spec describe(t) :: String.t()
  def describe(breakpoint) do
    conditions =
      for {k, v} <- breakpoint.conditions do
        case k do
          :address -> "contract address 0x#{Base.encode16(v, case: :lower)}"
        end
      end
      |> Enum.join(" ")

    state =
      case breakpoint.pc do
        :next -> "next"
        :start -> "start"
        nil -> "waiting"
      end

    "#{conditions} (#{state})" |> String.trim()
  end

  @doc """
  Returns all active breakpoints.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>]})
      iex> breakpoint = EVM.Debugger.Breakpoint.get_breakpoint(id)
      iex> breakpoints = EVM.Debugger.Breakpoint.get_breakpoints()
      iex> breakpoints |> Enum.count > 0
      true
      iex> breakpoints |> Enum.member?(breakpoint)
      true
  """
  @spec get_breakpoints() :: [t()]
  def get_breakpoints() do
    :ets.foldl(
      fn {_id, breakpoint}, acc ->
        [breakpoint | acc]
      end,
      [],
      @table
    )
  end

  @doc """
  Disables a given breakpoint.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>]})
      iex> EVM.Debugger.Breakpoint.disable_breakpoint(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], enabled: false}
  """
  @spec disable_breakpoint(id) :: t()
  def disable_breakpoint(breakpoint_id) do
    update_breakpoint(breakpoint_id, fn breakpoint ->
      %{breakpoint | enabled: false}
    end)
  end

  @doc """
  Enables a given breakpoint.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], enabled: false})
      iex> EVM.Debugger.Breakpoint.enable_breakpoint(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], enabled: true}
  """
  @spec enable_breakpoint(id) :: t()
  def enable_breakpoint(breakpoint_id) do
    update_breakpoint(breakpoint_id, fn breakpoint ->
      %{breakpoint | enabled: true}
    end)
  end

  @doc """
  Sets the pc to next so that this breakpoint
  will likely break on the next run.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>]})
      iex> EVM.Debugger.Breakpoint.set_next(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: :next}
  """
  @spec set_next(id) :: t()
  def set_next(breakpoint_id) do
    update_breakpoint(breakpoint_id, fn breakpoint ->
      %{breakpoint | pc: :next}
    end)
  end

  @doc """
  Clears the pc so that this breakpoint doesn't continue breaking.

  ## Examples

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: :next})
      iex> EVM.Debugger.Breakpoint.clear_pc_if_one_time_break(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: nil}

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: :start})
      iex> EVM.Debugger.Breakpoint.clear_pc_if_one_time_break(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: nil}

      iex> id = EVM.Debugger.Breakpoint.set_breakpoint(%EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: 5})
      iex> EVM.Debugger.Breakpoint.clear_pc_if_one_time_break(id) |> Map.put(:id, nil)
      %EVM.Debugger.Breakpoint{conditions: [address: <<1::160>>], pc: 5}
  """
  @spec clear_pc_if_one_time_break(id) :: t()
  def clear_pc_if_one_time_break(breakpoint_id) do
    update_breakpoint(breakpoint_id, fn breakpoint ->
      if breakpoint.pc in [:start, :next] do
        %{breakpoint | pc: nil}
      else
        breakpoint
      end
    end)
  end

  @spec update_breakpoint(id, (t -> t)) :: t
  defp update_breakpoint(breakpoint_id, fun) do
    breakpoint = get_breakpoint(breakpoint_id)

    updated_breakpoint = fun.(breakpoint)

    :ets.insert(@table, {breakpoint.id, updated_breakpoint})

    updated_breakpoint
  end

  # Returns a new id for the next breakpoint
  @spec next_id() :: id
  defp next_id() do
    case :ets.last(@table) do
      :"$end_of_table" -> 1
      key -> key + 1
    end
  end

  # Returns true if we should break on the next instruction

  # This is will be true if we're instructed to break on :next or :start, or
  # when the machine's breakpoint's pc matches the machine's pc.
  @spec break_on_next_pc?(t, EVM.MachineState.program_counter()) :: boolean()
  def break_on_next_pc?(breakpoint, pc) do
    case breakpoint.pc do
      nil -> false
      :next -> true
      :start -> true
      ^pc -> true
      _ -> false
    end
  end
end
