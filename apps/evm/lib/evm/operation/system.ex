defmodule EVM.Operation.System do
  alias EVM.Interface.AccountInterface
  alias EVM.BlockHeaderInfo

  alias EVM.{
    MachineState,
    ExecEnv,
    Address,
    Stack,
    Operation,
    MessageCall,
    Gas,
    Memory,
    SubState,
    Configuration,
    Address
  }

  @dialyzer {:no_return, callcode: 2}

  @doc """
  Create a new account with associated code.
  """
  @spec create(Operation.stack_args(), map()) :: Operation.op_result()
  def create([value, input_offset, input_size], vm_map = %{exec_env: exec_env}) do
    nonce = AccountInterface.get_account_nonce(exec_env.account_interface, exec_env.address)
    new_account_address = Address.new(exec_env.address, nonce)

    create_account([value, input_offset, input_size], vm_map, new_account_address)
  end

  @spec create2(Operation.stack_args(), map()) :: Operation.op_result()
  def create2(
        [value, input_offset, input_size, salt],
        vm_map = %{
          exec_env: exec_env,
          machine_state: machine_state
        }
      ) do
    {init_code, _machine_state} = EVM.Memory.read(machine_state, input_offset, input_size)
    new_account_address = Address.new(exec_env.address, salt, init_code)

    create_account([value, input_offset, input_size], vm_map, new_account_address)
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
      stack_depth: exec_env.stack_depth,
      static: exec_env.static,
      type: :call
    }

    MessageCall.call(message_call)
  end

  @doc """
  Message-call into this account with an alternative account’s code, but
  persisting the current values for sender and value.
  """
  @spec delegatecall(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def delegatecall([call_gas, to, in_offset, in_size, out_offset, out_size], %{
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
      value: exec_env.value_in_wei,
      execution_value: call_gas,
      data: data,
      stack_depth: exec_env.stack_depth,
      static: exec_env.static,
      type: :delegate_call
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
      stack_depth: exec_env.stack_depth,
      static: true,
      type: :static_call
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
        ...>   %{exec_env: exec_env, machine_state: machine_state, sub_state: EVM.SubState.empty()})
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
      stack_depth: exec_env.stack_depth,
      static: exec_env.static,
      type: :callcode
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
    words = Memory.get_active_words(mem_end)
    MachineState.maybe_set_active_words(machine_state, words)
  end

  @doc """
  We handle revert op code in Functions.is_normal_halting?/2 method. Here it's noop. We only pay for the memory.
  """
  @spec revert(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def revert([_mem_start, mem_end], %{machine_state: machine_state}) do
    words = Memory.get_active_words(mem_end)
    MachineState.maybe_set_active_words(machine_state, words)
  end

  @doc """
  Halt execution and register account for later deletion.
  Transfers `value` wei from callers account to the "refund account".

  Defined as SELFDESTRUCT in the Yellow Paper.

  Note:

  There was a consensus issue at some point (see Quirk #2 in
  http://martin.swende.se/blog/Ethereum_quirks_and_vulns.html). There is one
  test case witnessing the current consensus
  `GeneralStateTests/stSystemOperationsTest/suicideSendEtherPostDeath.json`.
  """
  @spec selfdestruct(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def selfdestruct([refund_address], %{exec_env: exec_env, sub_state: sub_state}) do
    to = Address.new(refund_address)

    new_exec_env =
      exec_env
      |> ExecEnv.transfer_balance_to(to)
      |> ExecEnv.clear_account_balance()

    new_substate =
      sub_state
      |> SubState.mark_account_for_destruction(exec_env.address)
      |> SubState.add_touched_account(to)

    %{exec_env: new_exec_env, sub_state: new_substate}
  end

  @spec create_account(Operation.stack_args(), map(), Address.t()) :: Operation.op_result()
  defp create_account(
         [value, input_offset, input_size],
         %{
           exec_env: exec_env,
           machine_state: machine_state,
           sub_state: sub_state
         },
         new_account_address
       ) do
    {data, machine_state} = EVM.Memory.read(machine_state, input_offset, input_size)

    account_balance =
      AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    block_header = BlockHeaderInfo.block_header(exec_env.block_header_info)

    is_allowed =
      value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth()

    available_gas =
      if Configuration.for(exec_env.config).fail_nested_operation_lack_of_gas?(exec_env.config) do
        machine_state.gas
      else
        EVM.Helpers.all_but_one_64th(machine_state.gas)
      end

    remaining_gas = machine_state.gas - available_gas

    {status, {updated_account_interface, n_gas, n_sub_state}} =
      if is_allowed do
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
          block_header,
          new_account_address,
          exec_env.config
        )
      else
        {:error, {exec_env.account_interface, available_gas, SubState.empty()}}
      end

    # Note if was exception halt or other failure on stack
    new_address =
      if status == :ok do
        new_account_address
      else
        <<0>>
      end

    new_address_for_machine_state = :binary.decode_unsigned(new_address)

    machine_state = %{
      machine_state
      | stack: Stack.push(machine_state.stack, new_address_for_machine_state),
        gas: n_gas + remaining_gas
    }

    exec_env = %{exec_env | account_interface: updated_account_interface}

    sub_state =
      n_sub_state
      |> SubState.merge(sub_state)
      |> SubState.add_touched_account(new_address)

    %{
      machine_state: machine_state,
      exec_env: exec_env,
      sub_state: sub_state
    }
  end
end
