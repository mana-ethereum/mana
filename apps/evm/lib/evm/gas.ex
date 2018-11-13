defmodule EVM.Gas do
  @moduledoc """
  Functions for interacting wth gas and costs of opscodes.
  """

  alias EVM.{
    Address,
    Configuration,
    ExecEnv,
    Helpers,
    MachineCode,
    MachineState,
    Operation
  }

  @type t :: EVM.val()
  @type gas_price :: EVM.Wei.t()
  @type cost_with_status :: {:original, t} | {:changed, t, t}

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
  @g_sload 200
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
  @g_extcodehash 400

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
    :gas,
    :returndatasize
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
                      :mstore8,
                      :shl,
                      :shr,
                      :sar
                    ] ++ @push_instrs ++ @dup_instrs ++ @swap_instrs
  @w_low_instr [:mul, :div, :sdiv, :mod, :smod, :signextend]
  @w_mid_instr [:addmod, :mulmod, :jump]
  @w_high_instr [:jumpi]
  @call_operations [:call, :callcode, :delegatecall, :staticcall]

  @type g_codedeposit :: unquote(@g_codedeposit)
  @type g_callstipend :: unquote(@g_callstipend)
  @doc """
  Returns the cost to execute the given a cycle of the VM. This is defined
  in Appenix H of the Yellow Paper, Eq.(294) and is denoted `C`.

  ## Examples

      iex> {_exec_env, cost} = EVM.Gas.cost(%EVM.MachineState{}, %EVM.ExecEnv{})
      iex> cost
      0
  """
  @spec cost(MachineState.t(), ExecEnv.t()) :: {ExecEnv.t(), t()}
  def cost(machine_state, exec_env) do
    {updated_exec_env, cost_with_status} = cost_with_status(machine_state, exec_env)

    cost =
      case cost_with_status do
        {:original, cost} -> cost
        {:changed, value, _} -> value
      end

    {updated_exec_env, cost}
  end

  @spec cost_with_status(MachineState.t(), ExecEnv.t()) :: {ExecEnv.t(), cost_with_status()}
  def cost_with_status(machine_state, exec_env) do
    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)

    {updated_exec_env, operation_cost} =
      case operation_cost(operation.sym, inputs, machine_state, exec_env) do
        {updated_exec_env, cost} -> {updated_exec_env, cost}
        cost -> {exec_env, cost}
      end

    memory_cost = memory_cost(operation.sym, inputs, machine_state)

    gas_cost = memory_cost + operation_cost

    cost_with_status =
      if exec_env.config.should_fail_nested_operation_lack_of_gas do
        {:original, gas_cost}
      else
        gas_cost_for_nested_operation(operation.sym,
          inputs: inputs,
          original_cost: gas_cost,
          machine_state: machine_state
        )
      end

    {updated_exec_env, cost_with_status}
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

  def memory_cost(:returndatacopy, [mem_offset, _code_offset, length], machine_state) do
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

  def memory_cost(:create2, [_value, in_offset, in_length, _salt], machine_state) do
    memory_expansion_cost(machine_state, in_offset, in_length) +
      @g_sha3word * MathHelper.bits_to_words(in_length)
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
         params,
         machine_state
       ) do
    [in_offset, in_length, out_offset, out_length] = Enum.take(params, -4)

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
  @spec operation_cost(atom(), list(EVM.val()), MachineState.t(), ExecEnv.t()) :: t | nil
  def operation_cost(operation, inputs, machine_state, exec_env)

  def operation_cost(:exp, [_base, exponent], _machine_state, exec_env) do
    @g_exp + exec_env.config.exp_byte_cost * MathHelper.integer_byte_size(exponent)
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
    exec_env.config.extcodecopy_cost + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(
        :returndatacopy,
        [_memory_offset, _code_offset, length],
        _machine_state,
        _exec_env
      ) do
    @g_verylow + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(:sha3, [_length, offset], _machine_state, _exec_env) do
    @g_sha3 + @g_sha3word * MathHelper.bits_to_words(offset)
  end

  def operation_cost(:sstore, [key, new_value], _machine_state, exec_env) do
    if exec_env.config.eip1283_sstore_gas_cost_changed do
      eip1283_sstore_gas_cost([key, new_value], exec_env)
    else
      basic_sstore_gas_cost([key, new_value], exec_env)
    end
  end

  def operation_cost(:selfdestruct, [address | _], _, exec_env) do
    address = Address.new(address)

    {updated_exec_env, non_existent_account} = ExecEnv.non_existent_account?(exec_env, address)

    {updated_exec_env, empty_account} =
      ExecEnv.non_existent_or_empty_account?(updated_exec_env, address)

    {updated_exec_env, is_new_account} =
      cond do
        !exec_env.config.empty_account_value_transfer && non_existent_account ->
          {updated_exec_env, true}

        exec_env.config.empty_account_value_transfer && empty_account ->
          {updated_exec_env, balance} = ExecEnv.balance(updated_exec_env)

          if balance > 0, do: {updated_exec_env, true}, else: {updated_exec_env, false}

        true ->
          {updated_exec_env, false}
      end

    cost =
      Configuration.for(exec_env.config).selfdestruct_cost(exec_env.config,
        new_account: is_new_account
      )

    {updated_exec_env, cost}
  end

  def operation_cost(
        :call,
        [call_gas, to_address, value, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    to_address = Address.new(to_address)

    {updated_exec_env, new_account_cost} = new_account_cost(exec_env, to_address, value)

    cost = exec_env.config.call_cost + call_value_cost(value) + new_account_cost + call_gas

    {updated_exec_env, cost}
  end

  def operation_cost(
        :staticcall,
        [gas_limit, to_address, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    to_address = Address.new(to_address)
    value = 0

    {updated_exec_env, new_account_cost} = new_account_cost(exec_env, to_address, value)

    cost = exec_env.config.call_cost + new_account_cost + gas_limit

    {updated_exec_env, cost}
  end

  def operation_cost(
        :delegatecall,
        [gas_limit, _to_address, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    exec_env.config.call_cost + gas_limit
  end

  def operation_cost(
        :callcode,
        [gas_limit, _to_address, value, _in_offset, _in_length, _out_offset, _out_length],
        _machine_state,
        exec_env
      ) do
    exec_env.config.call_cost + call_value_cost(value) + gas_limit
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
        exec_env.config.extcodecopy_cost

      operation == :create ->
        @g_create

      operation == :create2 ->
        @g_create

      operation == :blockhash ->
        @g_blockhash

      operation == :balance ->
        exec_env.config.balance_cost

      operation == :sload ->
        exec_env.config.sload_cost

      operation == :jumpdest ->
        @g_jumpdest

      operation == :extcodehash ->
        @g_extcodehash

      true ->
        0
    end
  end

  @spec callstipend() :: g_callstipend()
  def callstipend do
    @g_callstipend
  end

  @spec codedeposit_cost() :: g_codedeposit()
  def codedeposit_cost do
    @g_codedeposit
  end

  defp call_value_cost(0), do: 0
  defp call_value_cost(_), do: @g_callvalue

  defp new_account_cost(exec_env, address, value) do
    {updated_exec_env, non_existent_account} = ExecEnv.non_existent_account?(exec_env, address)

    {updated_exec_env, empty_account} =
      ExecEnv.non_existent_or_empty_account?(updated_exec_env, address)

    cond do
      !exec_env.config.empty_account_value_transfer && non_existent_account ->
        {updated_exec_env, @g_newaccount}

      exec_env.config.empty_account_value_transfer && value > 0 && empty_account ->
        {updated_exec_env, @g_newaccount}

      true ->
        {updated_exec_env, 0}
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

  @spec g_sreset() :: t
  def g_sreset, do: @g_sreset

  @spec g_sset() :: t
  def g_sset, do: @g_sset

  @spec g_sload() :: t
  def g_sload, do: @g_sload

  # EIP150
  @spec gas_cost_for_nested_operation(atom(), keyword()) ::
          {:original, t()} | {:changed, t(), t()}
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

      if remaining_gas >= 0 do
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

  defp eip1283_sstore_gas_cost([key, new_value], exec_env) do
    {updated_exec_env, initial_value} = get_initial_value(exec_env, key)
    {updated_exec_env, current_value} = get_current_value(updated_exec_env, key)

    cost =
      cond do
        current_value == new_value -> @g_sload
        initial_value == current_value && initial_value == 0 -> @g_sset
        initial_value == current_value && initial_value != 0 -> @g_sreset
        true -> @g_sload
      end

    {updated_exec_env, cost}
  end

  defp basic_sstore_gas_cost([key, new_value], exec_env) do
    {updated_exec_env, result} = ExecEnv.storage(exec_env, key)

    cost =
      case result do
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

    {updated_exec_env, cost}
  end

  defp get_initial_value(exec_env, key) do
    {updated_exec_env, result} = ExecEnv.initial_storage(exec_env, key)

    value =
      case result do
        :account_not_found -> 0
        :key_not_found -> 0
        {:ok, value} -> value
      end

    {updated_exec_env, value}
  end

  defp get_current_value(exec_env, key) do
    {updated_exec_env, result} = ExecEnv.storage(exec_env, key)

    value =
      case result do
        :account_not_found -> 0
        :key_not_found -> 0
        {:ok, value} -> value
      end

    {updated_exec_env, value}
  end
end
