defmodule EVM.Gas do
  @moduledoc """
  Functions for interacting wth gas and costs of opscodes.
  """

  alias EVM.MachineState
  alias EVM.MachineCode
  alias EVM.Operation
  alias EVM.ExecEnv

  @type t :: EVM.val
  @type gas_price :: EVM.Wei.t

  @g_zero 0  # Nothing paid for operations of the set Wzero.
  @g_base 2  # Amount of gas to pay for operations of the set Wbase.
  @g_verylow 3  # Amount of gas to pay for operations of the set Wverylow.
  @g_low 5  # Amount of gas to pay for operations of the set Wlow.
  @g_mid 8  # Amount of gas to pay for operations of the set Wmid.
  @g_high 10  # Amount of gas to pay for operations of the set Whigh.
  @g_extcode 20  # Amount of gas to pay for operations of the set Wextcode.
  @g_balance 20  # Amount of gas to pay for a BALANCE operation.
  @g_sload 50  # Paid for a SLOAD operation.
  @g_jumpdest 1  # Paid for a JUMPDEST operation.
  @g_sset 20000  # Paid for an SSTORE operation when the storage value is set to non-zero from zero.
  @g_sreset 5000  # Paid for an SSTORE operation when the storage value’s zeroness remains unchanged or is set to zero.
  @g_sclear 15000  # Refund given (added into refund counter) when the storage value is set to zero from non-zero.
  @g_suicide 24000  # Refund given (added into refund counter) for suiciding an account.
  @g_suicide 5000  # Amount of gas to pay for a SUICIDE operation.
  @g_create 32000  # Paid for a CREATE operation.
  @g_codedeposit 200  # Paid per byte for a CREATE operation to succeed in placing code into state.
  @g_call 40  # Paid for a CALL operation.
  @g_callvalue 9000  # Paid for a non-zero value transfer as part of the CALL operation.
  @g_callstipend 2300  # A stipend for the called contract subtracted from Gcallvalue for a non-zero value transfer.
  @g_newaccount 25000  # Paid for a CALL or SUICIDE operation which creates an account.
  @g_exp 10  # Partial payment for an EXP operation.
  @g_expbyte 10  # Partial payment when multiplied by dlog256(exponent)e for the EXP operation.
  @g_memory 3  # Paid for every additional word when expanding memory.
  @g_quad_coeff_div 512 # The divsor of quadratic costs
  @g_txcreate 32000  # Paid by all contract-creating transactions after the Homestead transition.
  @g_txdatazero 4  # Paid for every zero byte of data or code for a transaction.
  @g_txdatanonzero 68  # Paid for every non-zero byte of data or code for a transaction.
  @g_transaction 21000  # Paid for every transaction.
  @g_log 375  # Partial payment for a LOG operation.
  @g_logdata 8  # Paid for each byte in a LOG operation’s data.
  @g_logtopic 375  # Paid for each topic of a LOG operation.
  @g_sha3 30  # Paid for each SHA3 operation.
  @g_sha3word 6  # Paid for each word (rounded up) for input data to a SHA3 operation.
  @g_copy 3  # Partial payment for *COPY operations, multiplied by words copied, rounded up.
  @g_blockhash 20  # Payment for BLOCKHASH operation

  @w_zero_instr [:stop, :return, :suicide]
  @w_base_instr [:address, :origin, :caller, :callvalue, :calldatasize, :codesize, :gasprice, :coinbase, :timestamp, :number, :difficulty, :gaslimit, :pop, :pc, :msize, :gas]
  @push_instrs Enum.map(0..32, fn n -> :"push#{n}" end)
  @dup_instrs Enum.map(0..16, fn n -> :"dup#{n}" end)
  @swap_instrs Enum.map(0..16, fn n -> :"swap#{n}" end)
  @log_instrs Enum.map(1..4, fn n -> :"log#{n}" end)
  @w_very_low_instr [
    :add, :sub, :calldatacopy, :codecopy, :not_, :lt, :gt, :slt, :sgt, :eq, :iszero, :and_, :or_, :xor_,
    :byte, :calldataload, :mload, :mstore, :mstore8] ++
      @push_instrs ++ @dup_instrs ++ @swap_instrs
  @w_low_instr [:mul, :div, :sdiv, :mod, :smod, :signextend]
  @w_mid_instr [:addmod, :mulmod, :jump]
  @w_high_instr [:jumpi]
  @w_extcode_instr [:extcodesize]
  @call_operations [:call, :callcode, :delegatecall]
  @memory_operations [:mstore, :mstore8, :sha3, :codecopy, :extcodecopy, :calldatacopy, :mload]


  @doc """
  Returns the cost to execute the given a cycle of the VM. This is defined
  in Appenix H of the Yellow Paper, Eq.(220) and is denoted `C`.

  ## Examples

      # TODO: Figure out how to hand in state
      iex> EVM.Gas.cost(%EVM.MachineState{}, %EVM.ExecEnv{})
      0
  """
  @spec cost(MachineState.t, ExecEnv.t) :: t | nil
  def cost(machine_state, exec_env) do
    operation = MachineCode.current_operation(machine_state, exec_env)
    inputs = Operation.inputs(operation, machine_state)
    operation_cost = operation_cost(operation.sym, inputs, machine_state, exec_env)
    memory_cost = memory_cost(operation.sym, inputs, machine_state)

    memory_cost + operation_cost
  end

  def memory_cost(:calldatacopy, [memory_offset, _call_data_start, length], machine_state) do
    memory_expansion_cost(machine_state, memory_offset, length)
  end

  def memory_cost(:extcodecopy, [_address, _code_offset, memory_offset, length], machine_state) do
    if (memory_offset + length > EVM.max_int()) do
      0
    else
      memory_expansion_cost(machine_state, memory_offset, length)
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

  def memory_cost(:call, [_gas_limit, _to_address, _value, _in_offset, _in_length, out_offset, out_length], machine_state) do
    memory_expansion_cost(machine_state, out_offset, out_length)
  end

  def memory_cost(:create, [_value, in_offset, in_length], machine_state) do
    memory_expansion_cost(machine_state, in_offset, in_length)
  end

  def memory_cost(:return, [offset, length], machine_state) do
    memory_expansion_cost(machine_state, offset, length)
  end

  def memory_cost(_operation, _inputs, _machine_state), do: 0

  # From Eq 220: Cmem(μ′i)−Cmem(μi)
  def memory_expansion_cost(machine_state, offset, length) do
    memory_expansion_value = memory_expansion_value(machine_state.active_words, offset, length)

    if memory_expansion_value > machine_state.active_words do
      quadratic_memory_cost(memory_expansion_value) - quadratic_memory_cost(machine_state.active_words)
    else
      0
    end
  end


  # Eq 223
  def memory_expansion_value(
    active_words, # s
    offset,       # f
    length        # l
  ) do
    if length == 0 do
      active_words
    else
      max(active_words, round(:math.ceil((offset + length) / 32)))
    end
  end

  # Eq 222 - Cmem
  def quadratic_memory_cost(a) do
    linear_cost = a * @g_memory
    quadratic_cost = MathHelper.floor(:math.pow(a, 2) / @g_quad_coeff_div)

    linear_cost + quadratic_cost
  end

  @doc """
  Returns the operation cost for every possible operation. This is defined
  in Appendix H of the Yellow Paper.

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> exec_env = %EVM.ExecEnv{address: address, account_interface: account_interface}
      iex> EVM.Gas.operation_cost(:sstore, [], %EVM.MachineState{stack: [0, 0]}, exec_env)
      5000

      iex> EVM.Gas.operation_cost(:exp, [0, 0], %EVM.MachineState{}, exec_env)
      10

      iex> EVM.Gas.operation_cost(:exp, [0, 1024], %EVM.MachineState{}, exec_env)
      30

      iex> EVM.Gas.operation_cost(:jumpdest, [], nil, exec_env)
      1

      iex> EVM.Gas.operation_cost(:blockhash, [], nil, exec_env)
      20

      iex> EVM.Gas.operation_cost(:stop, [], nil, exec_env)
      0

      iex> EVM.Gas.operation_cost(:address, [], nil, exec_env)
      2

      iex> EVM.Gas.operation_cost(:push0, [], nil, exec_env)
      3

      iex> EVM.Gas.operation_cost(:mul, [], nil, exec_env)
      5

      iex> EVM.Gas.operation_cost(:addmod, [], nil, exec_env)
      8

      iex> EVM.Gas.operation_cost(:jumpi, [], nil, exec_env)
      10

      iex> EVM.Gas.operation_cost(:extcodesize, [], nil, exec_env)
      700

      iex> EVM.Gas.operation_cost(:sha3, [0, 0], %EVM.MachineState{stack: [0, 0]}, exec_env)
      30
      iex> EVM.Gas.operation_cost(:sha3, [10, 1024], %EVM.MachineState{stack: [10, 1024]}, exec_env)
      222

  """
  @spec operation_cost(atom(), list(EVM.val), EVM.state, MachineState.t) :: t | nil
  def operation_cost(operation \\ nil, inputs \\ nil, machine_state \\ nil, exec_env \\ nil)
  def operation_cost(:exp, [_base, exponent], _machine_state, _exec_env) do
    @g_exp + @g_expbyte * MathHelper.integer_byte_size(exponent)
  end

  def operation_cost(:codecopy, [_memory_offset, _code_offset, length], _machine_state, _exec_env) do
    @g_verylow + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(:calldatacopy, [_memory_offset, _code_offset, length], _machine_state, _exec_env) do
    @g_verylow + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(:extcodecopy, [_address, _code_offset, _mem_offset, length], _machine_state, _exec_env) do
    @g_extcode + @g_copy * MathHelper.bits_to_words(length)
  end

  def operation_cost(:sha3, [_length, offset], _machine_state, _exec_env) do
    @g_sha3 + @g_sha3word * MathHelper.bits_to_words(offset)
  end

  @doc """
  Returns the cost of a call to `sstore`. This is defined
  in Appenfix H.2. of the Yellow Paper under the
  definition of SSTORE, referred to as `C_SSTORE`.

  ## Examples

    iex> address = 0x0000000000000000000000000000000000000001
    iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
    iex> exec_env = %EVM.ExecEnv{address: address, account_interface: account_interface}
    iex> EVM.Gas.operation_cost(:sstore, [0, 0], %EVM.MachineState{}, exec_env)
    5000
    iex> EVM.Gas.operation_cost(:sstore, [0, 2], %EVM.MachineState{}, exec_env)
    20000
  """
  def operation_cost(:sstore, [key, new_value], _machine_state, exec_env) do
    old_value = ExecEnv.get_storage(exec_env, key)

    cond do
      new_value == 0 ->
        @g_sreset
      old_value == :account_not_found ->
        @g_sset
      old_value == :key_not_found ->
        @g_sset
      true ->
        @g_sreset
    end
  end

  def operation_cost(:call, [gas_limit, to_address, value, _in_offset, _in_length, _out_offset, _out_length], _machine_state, exec_env) do
    @g_call + call_value_cost(value) + new_account_cost(to_address, exec_env) + gas_limit
  end

  def operation_cost(operation, _inputs, _machine_state, _exec_env) do
    cond do
      operation in @w_very_low_instr -> @g_verylow
      operation in @w_zero_instr -> @g_zero
      operation in @w_base_instr -> @g_base
      operation in @w_low_instr -> @g_low
      operation in @w_mid_instr -> @g_mid
      operation in @w_high_instr -> @g_high
      operation in @w_extcode_instr -> @g_extcode
      operation in @call_operations -> @g_call
      operation == :create -> @g_create
      operation == :blockhash -> @g_blockhash
      operation == :balance -> @g_balance
      operation == :sload -> @g_sload
      operation == :jumpdest -> @g_jumpdest
      operation in @log_instrs -> 0
      true -> 0
    end
  end

  defp call_value_cost(value) do
    if value == 0 do
      0
    else
      @g_callvalue - @g_callstipend
    end
  end

  defp new_account_cost(address, exec_env) do
    if exec_env.account_interface
      |> EVM.Interface.AccountInterface.account_exists?(address) do
      0
    else
      @g_newaccount
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
    end |> Enum.sum
  end

  @doc "Paid by all contract-creating transactions after the Homestead transition."
  @spec g_txcreate() :: t
  def g_txcreate, do: @g_create

  @doc "Paid for every transaction."
  @spec g_transaction() :: t
  def g_transaction, do: @g_transaction

end
