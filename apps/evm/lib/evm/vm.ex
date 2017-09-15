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
  alias EVM.Operation

  @type output :: binary()

  @doc """
  This function computes the Ξ function Eq.(116) of the Section 9.4 of the Yellow Paper. This is the complete
  result of running a given program in the VM.

  ## Examples

      # Full program
      iex> EVM.VM.run(%{}, 24, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])})
      {%{}, 0, %EVM.SubState{}, <<0x08::256>>}

      # Program with implicit stop
      iex> EVM.VM.run(%{}, 9, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])})
      {%{}, 0, %EVM.SubState{}, ""}

      # Program with explicit stop
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :stop])})
      {%{}, 2, %EVM.SubState{}, ""}

      # Program with exception halt
      iex> EVM.VM.run(%{}, 5, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])})
      {nil, 5, %EVM.SubState{}, ""}
  """
  @spec run(EVM.state, Gas.t, ExecEnv.t) :: {EVM.state | nil, Gas.t, EVM.SubState.t, output}
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
      {%{}, %EVM.MachineState{pc: 2, gas: 2, stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])}, <<>>}

      iex> EVM.VM.exec(%{}, %EVM.MachineState{pc: 0, gas: 9, stack: []}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])})
      {%{}, %EVM.MachineState{pc: 6, gas: 0, stack: [8]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add])}, ""}

      iex> EVM.VM.exec(%{}, %EVM.MachineState{pc: 0, gas: 24, stack: []}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])})
      {%{},%EVM.MachineState{active_words: 1, memory: <<0x08::256>>, gas: 0, pc: 13, previously_active_words: 1, stack: []}, %EVM.SubState{logs: "", refund: 0, suicide_list: []}, %EVM.ExecEnv{account_interface: nil, address: nil, block_interface: nil, contract_interface: nil, data: nil, gas_price: nil, machine_code: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>, originator: nil, sender: nil, stack_depth: nil, value_in_wei: nil}, <<0x08::256>>}
  """
  @spec exec(EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state | nil, MachineState.t, SubState.t, ExecEnv.t, output}
  def exec(state, machine_state, sub_state, exec_env) do
    do_exec(state, machine_state, sub_state, exec_env, sub_state)
  end

  @spec do_exec(EVM.state, MachineState.t, SubState.t, ExecEnv.t, SubState.t) :: {EVM.state | nil, MachineState.t, SubState.t, ExecEnv.t, output}
  defp do_exec(state, machine_state, sub_state, exec_env, original_sub_state) do

    # Debugger generally runs here.
    {state, machine_state, sub_state, exec_env} = if EVM.Debugger.is_enabled? do
      case EVM.Debugger.is_breakpoint?(state, machine_state, sub_state, exec_env) do
        :continue -> {state, machine_state, sub_state, exec_env}
        breakpoint ->
          EVM.Debugger.break(breakpoint, state, machine_state, sub_state, exec_env)
      end
    else
      {state, machine_state, sub_state, exec_env}
    end

    case Functions.is_exception_halt?(state, machine_state, exec_env) do
      {:halt, _reason} ->
        # We're exception halting, undo it all.
        {nil, machine_state, original_sub_state, exec_env, <<>>} # Question: should we return the original sub-state?
      :continue ->
        {n_state, n_machine_state, n_sub_state, n_exec_env} = cycle(state, machine_state, sub_state, exec_env)
        if machine_state.gas < 0 do
          {nil, machine_state, original_sub_state, exec_env, <<>>}
        else
          case Functions.is_normal_halting?(machine_state, exec_env) do
            nil -> do_exec(n_state, n_machine_state, n_sub_state, n_exec_env, original_sub_state) # continue execution
            output -> {n_state, n_machine_state, n_sub_state, n_exec_env, output} # break execution and return
          end
        end
    end
  end

  @doc """
  Runs a single cycle of our VM returning the new state, defined as `O`
  in the Yellow Paper, Eq.(131).

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:evm_vm_test_2))
      iex> EVM.VM.cycle(state, %EVM.MachineState{pc: 0, gas: 5, stack: [1, 2]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])})
      {%MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :evm_vm_test_2}, root_hash: MerklePatriciaTree.Trie.empty_trie_root_hash}, %EVM.MachineState{pc: 1, gas: 2, stack: [3]}, %EVM.SubState{}, %EVM.ExecEnv{machine_code: EVM.MachineCode.compile([:add])}}
  """
  @spec cycle(EVM.state, MachineState.t, SubState.t, ExecEnv.t) :: {EVM.state, MachineState.t, SubState.t, ExecEnv.t}
  def cycle(state, machine_state, sub_state, exec_env) do
    operation = MachineCode.current_instruction(machine_state, exec_env) |> Operation.decode
    {updated_state, updated_machine_state, sub_state, exec_env} = Operation.run_operation(operation, state, machine_state, sub_state, exec_env)

    cost = Gas.cost(operation, state, machine_state, updated_machine_state)

    updated_machine_state = updated_machine_state
      |> MachineState.subtract_gas(cost)
      |> MachineState.next_pc(exec_env)


    {updated_state, updated_machine_state, sub_state, exec_env}
  end

end
