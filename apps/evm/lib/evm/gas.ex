defmodule EVM.Gas do
  @moduledoc """
  Functions for interacting wth gas and costs of opscodes.
  """

  alias EVM.{
    MachineState,
    MachineCode,
    Operation,
    Address,
    ExecEnv,
    Configuration,
    Helpers
  }

  @type t :: EVM.val()
  @type gas_price :: EVM.Wei.t()

  # Nothing paid for operations of the set W_zero.
  @g_zero 0
  # Amount of gas to pay for operations of the set W_base.
  @g_base 2
  # Amount of gas to pay for operations of the set W_verylow.
  @g_verylow 3
  # Amount of gas to pay for operations of the set W_low.
  @g_low 5
  # Amount of gas to pay for operations of the set W_mid.
  @g_mid 8
  # Amount of gas to pay for operations of the set W_high.
  @g_high 10
  # Paid for a JUMPDEST operation.
  @g_jumpdest 1
  # Paid for an SSTORE operation when the storage value is set to non-zero from zero.
  @g_sset 20_000
  # Paid for an SSTORE operation when the storage value’s zeroness remains unchanged or is set to zero.
  @g_sreset 5000
  # Paid for a CREATE operation.
  @g_create 32_000
  # Paid per byte for a CREATE operation to succeed in placing code into state.
  @g_codedeposit 200
  # Paid for a non-zero value transfer as part of the CALL operation.
  @g_callvalue 9000
  # A stipend for the called contract subtracted from Gcallvalue for a non-zero value transfer.
  @g_callstipend 2300
  # Paid for a CALL or SELFDESTRUCT operation which creates an account.
  @g_newaccount 25_000
  # Partial payment for an EXP operation.
  @g_exp 10
  # Paid for every additional word when expanding memory.
  @g_memory 3
  # The divsor of quadratic costs
  @g_quad_coeff_div 512
  # Paid for every zero byte of data or code for a transaction.
  @g_txdatazero 4
  # Paid for every non-zero byte of data or code for a transaction.
  @g_txdatanonzero 68
  # Paid for every transaction.
  @g_transaction 21_000
  # Partial payment for a LOG operation.
  @g_log 375
  # Paid for each byte in a LOG operation’s data.
  @g_logdata 8
  # Paid for each topic of a LOG operation.
  @g_logtopic 375
  # Paid for each SHA3 operation.
  @g_sha3 30
  # Paid for each word (rounded up) for input data to a SHA3 operation.
  @g_sha3word 6
  # Partial payment for *COPY operations, multiplied by words copied, rounded up.
  @g_copy 3
  # Payment for BLOCKHASH operation
  @g_blockhash 20

  @w_zero_instr [:stop, :return, :revert]
  @w_base_instr [
    :address,
    :origin,
    :caller,
    :callvalue,
    :calldatasize,
    :codesize,
    :gasprice,
    :coinbase,
    :timestamp,
    :number,
    :difficulty,
    :gaslimit,
    :pop,
    :pc,
    :msize,
    :gas
  ]
  @push_instrs Enum.map(0..32, fn n -> :"push#{n}" end)
  @dup_instrs Enum.map(0..16, fn n -> :"dup#{n}" end)
  @swap_instrs Enum.map(0..16, fn n -> :"swap#{n}" end)
  @w_very_low_instr [
                      :add,
                      :sub,
                      :calldatacopy,
                      :codecopy,
                      :not_,
                      :lt,
                      :gt,
                      :slt,
                      :sgt,
                      :eq,
                      :iszero,
                      :and_,
                      :or_,
                      :xor_,
                      :byte,
                      :calldataload,
                      :mload,
                      :mstore,
                      :mstore8
                    ] ++ @push_instrs ++ @dup_instrs ++ @swap_instrs
  @w_low_instr [:mul, :div, :sdiv, :mod, :smod, :signextend]
  @w_mid_instr [:addmod, :mulmod, :jump]
  @w_high_instr [:jumpi]
  @call_operations [:call, :callcode, :delegatecall, :staticcall]

  @doc """
  Returns the cost to execute the given a cycle of the VM. This is defined
  in Appenix H of the Yellow Paper, Eq.(294) and is denoted `C`.

  ## Examples

      # TODO: Figure out how to hand in state
      iex> EVM.Gas.cost(%EVM.MachineState{}, %EVM.ExecEnv{})
      0
  """
  @spec cost(MachineState.t(), ExecEnv.t(), keyword()) :: t | nil | {atom(), t | nil}
  def cost(machine_state, exec_env, params \\ []) do
    with_status = Keyword.get(params, :with_status)

    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)
    operation_cost = operation_cost(operation.sym, inputs, machine_state, exec_env)
    memory_cost = memory_cost(operation.sym, inputs, machine_state)

    gas_cost = memory_cost + operation_cost

    if Configuration.fail_nested_operation_lack_of_gas?(exec_env.config) do
      if with_status, do: {:original, gas_cost}, else: gas_cost
    else
      cost_change_result =
        gas_cost_for_nested_operation(
          operation.sym,
          inputs: inputs,
          original_cost: gas_cost,
          machine_state: machine_state
        )

      case cost_change_result do
        {status, value} -> if with_status, do: {status, value}, else: value
        {status, value, call_gass} -> if with_status, do: {status, value, call_gass}, else: value
      end
    end
  end

  def memory_cost(:calldatacopy, [memory_offset, _call_data_start, length], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, length)
  end

  def memory_cost(:extcodecopy, [_address, mem_offset, _code_offset, length], machine_state) do
    if mem_offset + length > EVM.max_int() do
      0
    else
      memory_expansion_cost(machine_state, mem_offset, length)
    end
  end

  def memory_cost(:codecopy, [memory_offset, _code_offset, length], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, length)
  end

  def memory_cost(:mload, [memory_offset], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, 32)
  end

  def memory_cost(:mstore8, [memory_offset, _value], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, 1)
  end

  def memory_cost(:sha3, [memory_offset, length], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, length)
  end

  def memory_cost(:mstore, [memory_offset, _value], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, 32)
  end

  def memory_cost(:call, stack_args, machine_state) do
    call_memory_cost(stack_args, machine_state)
  end

  def memory_cost(:callcode, stack_args, machine_state) do
    call_memory_cost(stack_args, machine_state)
  end

  def memory_cost(:staticcall, stack_args, machine_state) do
    call_memory_cost(stack_args, machine_state)
  end

  def memory_cost(:delegatecall, stack_args, machine_state) do
    stack_args = List.insert_at(stack_args, 2, 0)

    call_memory_cost(stack_args, machine_state)
  end

  def memory_cost(:create, [_value, in_offset, in_length], machine_state) do
    memory_expansion_cost(machine_state, in_offset, in_length)
  end

  def memory_cost(:return, [offset, length], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:revert, [offset, length], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:log0, [offset, length | _], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:log1, [offset, length | _], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:log2, [offset, length | _], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:log3, [offset, length | _], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(:log4, [offset, length | _], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(_operation, _inputs, _machine_state), do: 0

  @spec call_memory_cost(Operation.stack_args(), MachineState.t()) :: t
  defp call_memory_cost(
         [_gas_limit, _to_address, _value, in_offset, in_length, out_offset, out_length],
         machine_state
       ) do
    out_memory_cost = memory_expansion_cost(machine_state, out_offset, out_length)
    in_memory_cost = memory_expansion_cost(machine_state, in_offset, in_length)

    max(out_memory_cost, in_memory_cost)
  end

  # From Eq. (294): C_mem(μ′_i) − C_mem(μ_i)
  def memory_expansion_cost(machine_state, offset, length) do
    memory_expansion_value = memory_expansion_value(machine_state.active_words, offset, length)

    if memory_expansion_value > machine_state.active_words do
      quadratic_memory_cost(memory_expansion_value) -
        quadratic_memory_cost(machine_state.active_words)
    else
      0
    end
  end

  # Eq. (223)
  def memory_expansion_value(
        # s
        active_words,
        # f
        offset,
        # l
        size
      ) do
    if size == 0 do
      active_words
    else
      max(active_words, round(:math.ceil((offset + size) / 32)))
    end
  end

  # Eq. (296)
  def quadratic_memory_cost(a) do
    linear_cost = a * @g_memory
    quadratic_cost = MathHelper.floor(:math.pow(a, 2) / @g_quad_coeff_div)

    linear_cost + quadratic_cost
  end

  @doc """
  Returns the operation cost for every possible operation.
  This is defined in Appendix H of the Yellow Paper.
  """
  @spec operation_cost(atom(), list(EVM.val()), list(EVM.val()), MachineState.t()) :: t | nil
  def operation_cost(operation \\ nil, inputs \\ nil, machine_state \\ nil, exec_env \\ nil)

  def operation_cost(:exp, [_base, exponent], _machine_state, exec_env) do
    @g_exp + Configuration.exp_byte_cost(exec_env.config) * MathHelper.integer_byte_size(exponent)
  end

  def operation_cost(:codecopy, [_memory_offset, _code_offset, length], _machine_state, _exec_env) do
    @g_verylow + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(
        :calldatacopy,
        [_memory_offset, _code_offset, length],
        _machine_state,
        _exec_env
      ) do
    @g_verylow + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(
        :extcodecopy,
        [_address, _code_offset, _mem_offset, length],
        _machine_state,
        exec_env
      ) do
    Configuration.extcodecopy_cost(exec_env.config) + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(:sha3, [_length, offset], _machine_state, _exec_env) do
    @g_sha3 + @g_sha3word * MathHelper.bits_to_words(offset)
  end

  def operation_cost(:sstore, [key, new_value], _machine_state, exec_env) do
    case ExecEnv.get_storage(exec_env, key) do
      :account_not_found ->
        @g_sset

      :key_not_found ->
        if new_value != 0 do
          @g_sset
        else
          @g_sreset
        end

      {:ok, value} ->
        if new_value != 0 && value == 0 do
          @g_sset
        else
          @g_sreset
        end
    end
  end

  def operation_cost(:selfdestruct, [address | _], _, exec_env) do
    address = Address.new(address)

    is_new_account =
      cond do
        !Configuration.empty_account_value_transfer?(exec_env.config) &&
            ExecEnv.non_existent_account?(exec_env, address) ->
          true

        Configuration.empty_account_value_transfer?(exec_env.config) &&
          ExecEnv.non_existent_or_empty_account?(exec_env, address) &&
            ExecEnv.get_balance(exec_env) > 0 ->
          true

        true ->
          false
      end

    Configuration.selfdestruct_cost(exec_env.config, new_account: is_new_account)
  end

  def operation_cost(
        :call,
        [call_gas, to_address, value, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    to_address = Address.new(to_address)

    Configuration.call_cost(exec_env.config) + call_value_cost(value) +
      new_account_cost(exec_env, to_address, value) + call_gas
  end

  def operation_cost(
        :staticcall,
        [gas_limit, to_address, value, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    to_address = Address.new(to_address)

    Configuration.call_cost(exec_env.config) + call_value_cost(value) +
      new_account_cost(exec_env, to_address, value) + gas_limit
  end

  def operation_cost(
        :delegatecall,
        [gas_limit, _to_address, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    Configuration.call_cost(exec_env.config) + gas_limit
  end

  def operation_cost(
        :callcode,
        [gas_limit, _to_address, value, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    Configuration.call_cost(exec_env.config) + call_value_cost(value) + gas_limit
  end

  def operation_cost(:log0, [_offset, size | _], _machine_state, _exec_env) do
    @g_log + @g_logdata * size
  end

  def operation_cost(:log1, [_offset, size | _], _machine_state, _exec_env) do
    @g_log + @g_logdata * size + @g_logtopic
  end

  def operation_cost(:log2, [_offset, size | _], _machine_state, _exec_env) do
    @g_log + @g_logdata * size + @g_logtopic * 2
  end

  def operation_cost(:log3, [_offset, size | _], _machine_state, _exec_env) do
    @g_log + @g_logdata * size + @g_logtopic * 3
  end

  def operation_cost(:log4, [_offset, size | _], _machine_state, _exec_env) do
    @g_log + @g_logdata * size + @g_logtopic * 4
  end

  # credo:disable-for-next-line
  def operation_cost(operation, _inputs, _machine_state, exec_env) do
    cond do
      operation in @w_very_low_instr ->
        @g_verylow

      operation in @w_zero_instr ->
        @g_zero

      operation in @w_base_instr ->
        @g_base

      operation in @w_low_instr ->
        @g_low

      operation in @w_mid_instr ->
        @g_mid

      operation in @w_high_instr ->
        @g_high

      operation == :extcodesize ->
        Configuration.extcodecopy_cost(exec_env.config)

      operation == :create ->
        @g_create

      operation == :blockhash ->
        @g_blockhash

      operation == :balance ->
        Configuration.balance_cost(exec_env.config)

      operation == :sload ->
        Configuration.sload_cost(exec_env.config)

      operation == :jumpdest ->
        @g_jumpdest

      true ->
        0
    end
  end

  @spec callstipend() :: integer()
  def callstipend do
    @g_callstipend
  end

  @spec codedeposit_cost() :: integer()
  def codedeposit_cost do
    @g_codedeposit
  end

  defp call_value_cost(0), do: 0
  defp call_value_cost(_), do: @g_callvalue

  defp new_account_cost(exec_env, address, value) do
    cond do
      !Configuration.empty_account_value_transfer?(exec_env.config) &&
          ExecEnv.non_existent_account?(exec_env, address) ->
        @g_newaccount

      Configuration.empty_account_value_transfer?(exec_env.config) && value > 0 &&
          ExecEnv.non_existent_or_empty_account?(exec_env, address) ->
        @g_newaccount

      true ->
        0
    end
  end

  @doc """
  Returns the gas cost for G_txdata{zero, nonzero} as defined in
  Appendix G (Fee Schedule) of the Yellow Paper.

  This implements `g_txdatazero` and `g_txdatanonzero`

  ## Examples

      iex> EVM.Gas.g_txdata(<<1, 2, 3, 0, 4, 5>>)
      5 * 68 + 4

      iex> EVM.Gas.g_txdata(<<0>>)
      4

      iex> EVM.Gas.g_txdata(<<0, 0>>)
      8

      iex> EVM.Gas.g_txdata(<<>>)
      0
  """
  @spec g_txdata(binary()) :: t
  def g_txdata(data) do
    for <<byte <- data>> do
      case byte do
        0 -> @g_txdatazero
        _ -> @g_txdatanonzero
      end
    end
    |> Enum.sum()
  end

  @doc "Paid by all contract-creating transactions after the Homestead transition."
  @spec g_txcreate() :: t
  def g_txcreate, do: @g_create

  @doc "Paid for every transaction."
  @spec g_transaction() :: t
  def g_transaction, do: @g_transaction

  # EIP150
  @spec gas_cost_for_nested_operation(atom(), keyword()) :: {atom(), integer()}
  defp gas_cost_for_nested_operation(
         operation,
         inputs: inputs,
         original_cost: original_cost,
         machine_state: machine_state
       ) do
    if operation in @call_operations do
      stack_exec_gas = List.first(inputs)
      call_cost_without_exec_gas = original_cost - stack_exec_gas
      remaining_gas = machine_state.gas - call_cost_without_exec_gas

      if remaining_gas > 0 do
        new_call_gas = Helpers.all_but_one_64th(remaining_gas)
        new_gas_cost = new_call_gas + call_cost_without_exec_gas

        if new_gas_cost < original_cost do
          {:changed, new_gas_cost, new_call_gas}
        else
          {:original, original_cost}
        end
      else
        # will fail in EVM.Functions.is_exception_halt?
        {:original, original_cost}
      end
    else
      {:original, original_cost}
    end
  end
end
