defmodule EVM.Operation.System do
  alias EVM.Interface.{AccountInterface, BlockInterface}
  alias EVM.{MachineState, ExecEnv, Address, Stack, Operation, MessageCall, Gas, Memory, SubState}

  @dialyzer {:no_return, callcode: 2}

  @doc """
  Create a new account with associated code.
  """
  @spec create(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def create([value, input_offset, input_size], %{
        exec_env: exec_env,
        machine_state: machine_state,
        sub_state: sub_state
      }) do
    {data, machine_state} = EVM.Memory.read(machine_state, input_offset, input_size)

    account_balance =
      AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed =
      value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth()

    {status, {updated_account_interface, n_gas, n_sub_state}} =
      if is_allowed do
        available_gas = machine_state.gas

        {account_interface, _nonce} =
          AccountInterface.increment_account_nonce(exec_env.account_interface, exec_env.address)

        n_exec_env = %{exec_env | account_interface: account_interface}

        AccountInterface.create_contract(
          n_exec_env.account_interface,
          # sender
          n_exec_env.address,
          # originator
          n_exec_env.originator,
          # available_gas
          available_gas,
          # gas_price
          n_exec_env.gas_price,
          # endowment
          value,
          # init_code
          data,
          # stack_depth
          n_exec_env.stack_depth + 1,
          # block_header
          block_header
        )
      else
        {:error, {exec_env.account_interface, machine_state.gas, SubState.empty()}}
      end

    # Note if was exception halt or other failure on stack
    result =
      if status == :ok do
        nonce =
          exec_env.account_interface
          |> AccountInterface.get_account_nonce(exec_env.address)

        EVM.Address.new(exec_env.address, nonce)
      else
        0
      end

    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, result), gas: n_gas}
    exec_env = %{exec_env | account_interface: updated_account_interface}

    sub_state = %SubState{
      refund: n_sub_state.refund + sub_state.refund,
      selfdestruct_list: n_sub_state.selfdestruct_list ++ sub_state.selfdestruct_list,
      logs: sub_state.logs
    }

    %{
      machine_state: machine_state,
      exec_env: exec_env,
      sub_state: sub_state
    }
  end

  @doc """
    Message-call into an account.
    Transfer `value` wei from callers account to callees account then run the code in that account.
  """
  @spec call(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def call([call_gas, to, value, in_offset, in_size, out_offset, out_size], %{
        exec_env: exec_env,
        machine_state: machine_state,
        sub_state: sub_state
      }) do
    to = Address.new(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    call_gas = if value != 0, do: call_gas + Gas.callstipend(), else: call_gas

    message_call = %MessageCall{
      current_exec_env: exec_env,
      current_machine_state: machine_state,
      current_sub_state: sub_state,
      output_params: {out_offset, out_size},
      sender: exec_env.address,
      originator: exec_env.originator,
      recipient: to,
      code_owner: to,
      gas_price: exec_env.gas_price,
      value: value,
      execution_value: call_gas,
      data: data,
      stack_depth: exec_env.stack_depth
    }

    MessageCall.call(message_call)
  end

  @doc """
  Message-call into this account with an alternative account’s code, but
  persisting the current values for sender and value.
  """
  @spec delegatecall(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def delegatecall([_call_gas, to, in_offset, in_size, out_offset, out_size], %{
        exec_env: exec_env,
        machine_state: machine_state,
        sub_state: sub_state
      }) do
    to = Address.new(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    message_call = %MessageCall{
      current_exec_env: exec_env,
      current_machine_state: machine_state,
      current_sub_state: sub_state,
      output_params: {out_offset, out_size},
      sender: exec_env.sender,
      originator: exec_env.originator,
      recipient: exec_env.address,
      code_owner: to,
      gas_price: exec_env.gas_price,
      value: 0,
      execution_value: exec_env.value_in_wei,
      data: data,
      stack_depth: exec_env.stack_depth
    }

    MessageCall.call(message_call)
  end

  @doc """
  Static message-call into an account. Exactly equivalent to CALL except:
  The argument μs[2] is replaced with 0.
  """
  @spec staticcall(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def staticcall([call_gas, to, in_offset, in_size, out_offset, out_size], %{
        exec_env: exec_env,
        machine_state: machine_state,
        sub_state: sub_state
      }) do
    to = Address.new(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    message_call = %MessageCall{
      current_exec_env: exec_env,
      current_machine_state: machine_state,
      current_sub_state: sub_state,
      output_params: {out_offset, out_size},
      sender: exec_env.address,
      originator: exec_env.originator,
      recipient: to,
      code_owner: to,
      gas_price: exec_env.gas_price,
      value: 0,
      execution_value: call_gas,
      data: data,
      stack_depth: exec_env.stack_depth
    }

    MessageCall.call(message_call)
  end

  @doc """
  Exactly equivalent to `call` except  the recipient is in fact the same account as at present, simply that the code is overwritten.

    ## Examples

        iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{})
        iex> exec_env = %EVM.ExecEnv{
        ...>   account_interface: account_interface,
        ...>   sender: <<0::160>>,
        ...>   address: <<5::160>>
        ...> }
        iex> machine_state = %EVM.MachineState{gas: 100000}
        iex> %{machine_state: machine_state} =
        ...> EVM.Operation.System.callcode([10, 1, 1, 0, 0, 0, 0],
        ...>   %{exec_env: exec_env, machine_state: machine_state})
        iex> EVM.Stack.peek(machine_state.stack)
        0
  """
  @spec callcode(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def callcode(
        [call_gas, to, value, in_offset, in_size, out_offset, out_size],
        %{exec_env: exec_env, machine_state: machine_state, sub_state: sub_state}
      ) do
    to = Address.new(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    call_gas = if value != 0, do: call_gas + Gas.callstipend(), else: call_gas

    message_call = %MessageCall{
      current_exec_env: exec_env,
      current_machine_state: machine_state,
      current_sub_state: sub_state,
      output_params: {out_offset, out_size},
      sender: exec_env.address,
      originator: exec_env.originator,
      recipient: exec_env.address,
      code_owner: to,
      gas_price: exec_env.gas_price,
      value: value,
      execution_value: call_gas,
      data: data,
      stack_depth: exec_env.stack_depth
    }

    MessageCall.call(message_call)
  end

  @doc """
  Halt execution returning output data,

  ## Examples

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 0}})
      %EVM.MachineState{active_words: 2}

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 5}})
      %EVM.MachineState{active_words: 5}
  """
  @spec return(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def return([_mem_start, mem_end], %{machine_state: machine_state}) do
    # We may have to bump up number of active words

    words = Memory.get_active_words(mem_end)

    MachineState.maybe_set_active_words(machine_state, words)
  end

  @doc """
  We handle revert op code in Functions.is_normal_halting?/2 method. Here it's noop. We only pay for the memory.
  """
  @spec revert(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def revert([_mem_start, mem_end], %{machine_state: machine_state}) do
    # We may have to bump up number of active words

    words = Memory.get_active_words(mem_end)

    MachineState.maybe_set_active_words(machine_state, words)
  end

  @doc """
  Halt execution and register account for later deletion.
  Transfers `value` wei from callers account to the "refund account".
  Address of the "refund account" is the first 20 bytes in the stack.

  Defined as SELFDESTRUCT in the Yellow Paper.
  """
  @spec selfdestruct(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def selfdestruct([refund_address], %{exec_env: exec_env, sub_state: sub_state}) do
    to = Address.new(refund_address)
    balance = AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    new_exec_env =
      exec_env
      |> ExecEnv.transfer_wei_to(to, balance)

    new_substate = %{
      sub_state
      | selfdestruct_list: sub_state.selfdestruct_list ++ [exec_env.address]
    }

    %{exec_env: new_exec_env, sub_state: new_substate}
  end
end
