defmodule EVM.VM do
  @moduledoc """
  The core of the EVM which runs operations based on the
  opcodes of a contract during a transfer or message call.
  """

  alias EVM.SubState
  alias EVM.MachineCode
  alias EVM.MachineState
  alias EVM.ExecEnv
  alias EVM.Functions
  alias EVM.Gas
  alias EVM.Instruction

  @type output :: binary()

  @doc """
  This function computes the Ξ function Eq.(116) of the Section 9.4 of the Yellow Paper. This is the complete
  result of running a given program in the VM.

  ## Examples

      # Full program
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])})
      {%{}, 5, %EVM.SubState{}, <<0x08::256>>}

      # Program with implicit stop
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])})
      {%{}, 5, %EVM.SubState{}, ""}

      # Program with explicit stop
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :stop])})
      {%{}, 5, %EVM.SubState{}, ""}

      # Program with exception halt
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])})
      {nil, 5, %EVM.SubState{}, ""}
  """
  @spec run(EVM.state, Gas.t, ExecEnv.t) :: {EVM.state, Gas.t, EVM.SubState.t, output}
  def run(state, gas, exec_env) do
    machine_state = %EVM.MachineState{gas: gas}
    sub_state = %EVM.SubState{}

    # Note, we drop exec env from return value
    {n_state, n_machine_state, n_sub_state, _n_exec_env, output} = exec(state, machine_state, sub_state, exec_env)

    {n_state, n_machine_state.gas, n_sub_state, output}
  end

  @doc """
  Runs a cycle of our VM in a recursive fashion, defined as `X`, Eq.(122) of the
  Yellow Paper. This function halts when return is called or an exception raised.

  TODO: Add gas to return

  ## Examples

      iex> EVM.VM.exec(%{}, %EVM.MachineState{pc: 0, gas: 5, stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])})
      {%{}, %EVM.MachineState{pc: 2, gas: 5, stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])}, <<>>}

      iex> EVM.VM.exec(%{}, %EVM.MachineState{pc: 0, gas: 5, stack: []}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])})
      {%{}, %EVM.MachineState{pc: 6, gas: 5, stack: [8]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])}, ""}

      iex> EVM.VM.exec(%{}, %EVM.MachineState{pc: 0, gas: 5, stack: []}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])})
      {%{}, %EVM.MachineState{active_words: 1, memory: <<0x08::256>>, pc: 13, gas: 5, stack: []}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])}, <<0x08::256>>}
  """
  @spec exec(EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state | nil, MachineState.t, SubState.t, ExecEnv.t, output}
  def exec(state, machine_state, sub_state, exec_env) do
    do_exec(state, machine_state, sub_state, exec_env, sub_state)
  end

  @spec do_exec(EVM.state, MachineState.t, SubState.t, ExecEnv.t, SubState.t) :: {EVM.state | nil, MachineState.t, SubState.t, ExecEnv.t, output}
  defp do_exec(state, machine_state, sub_state, exec_env, original_sub_state) do
    case Functions.is_exception_halt?(state, machine_state, exec_env) do
      {:halt, _reason} ->
        # We're exception halting, undo it all.
        {nil, machine_state, original_sub_state, exec_env, <<>>} # Question: should we return the original sub-state?
      :continue ->
        {n_state, n_machine_state, n_sub_state, n_exec_env} = cycle(state, machine_state, sub_state, exec_env)

        case Functions.is_normal_halting?(machine_state, exec_env) do
          nil -> do_exec(n_state, n_machine_state, n_sub_state, n_exec_env, original_sub_state) # continue execution
          output -> {n_state, n_machine_state, n_sub_state, n_exec_env, output} # break execution and return
        end
    end
  end

  @doc """
  Runs a single cycle of our VM returning the new state, defined as `O`
  in the Yellow Paper, Eq.(131).

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:evm_vm_test))
      iex> EVM.VM.cycle(state, %EVM.MachineState{pc: 0, gas: 5, stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])})
      {%MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :evm_vm_test}, root_hash: <<128>>}, %EVM.MachineState{pc: 1, gas: 5, stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])}}
  """
  @spec cycle(EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
  def cycle(state, machine_state, sub_state, exec_env) do
    cost = Gas.cost(state, machine_state, exec_env)

    instruction = MachineCode.current_instruction(machine_state, exec_env) |> Instruction.decode

    {state, machine_state, sub_state, exec_env} = Instruction.run_instruction(instruction, state, machine_state, sub_state, exec_env)

    machine_state = machine_state
      |> MachineState.subtract_gas(cost)
      |> MachineState.next_pc(exec_env)

    {state, machine_state, sub_state, exec_env}
  end

end