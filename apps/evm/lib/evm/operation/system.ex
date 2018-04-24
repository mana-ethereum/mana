defmodule EVM.Operation.System do
  alias EVM.MachineState
  alias EVM.ExecEnv
  alias EVM.Interface.AccountInterface
  alias EVM.Interface.BlockInterface
  alias EVM.Helpers
  alias EVM.Address
  alias EVM.Stack
  alias EVM.Operation

  @doc """
  Create a new account with associated code.

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_map = %{<<100::160>> => %{balance: 5_000, nonce: 5}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(account_map, %{gas: 500, sub_state: nil, output: "output"})
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, address: <<100::160>>, account_interface: account_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state} =
      ...>   EVM.Operation.System.create(
      ...>     [1_000, 5, 5],
      ...>     %{exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 300, stack: [0x601bcc2189b7096d8dfaa6f74efeebef20486d0d, 1], active_words: 1, memory: "________input"}
  """
  @spec create(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def create([value, in_offset, in_size], %{exec_env: exec_env, machine_state: machine_state}) do
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    account_balance =
      AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed =
      value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth()

    {updated_account_interface, n_gas, _n_sub_state} =
      if is_allowed do
        available_gas = Helpers.all_but_one_64th(machine_state.gas)

        AccountInterface.create_contract(
          exec_env.account_interface,
          # sender
          exec_env.address,
          # originator
          exec_env.originator,
          # available_gas
          available_gas,
          # gas_price
          exec_env.gas_price,
          # endowment
          value,
          # init_code
          data,
          # stack_depth
          exec_env.stack_depth + 1,
          # block_header
          block_header
        )
      else
        {exec_env.account_interface, machine_state.gas, nil}
      end

    # Note if was exception halt or other failure on stack
    result =
      if is_allowed do
        nonce =
          exec_env.account_interface
          |> AccountInterface.get_account_nonce(exec_env.address)

        EVM.Address.new(exec_env.address, nonce)
      else
        0
      end

    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, result)}
    exec_env = %{exec_env | account_interface: updated_account_interface}

    %{
      machine_state: machine_state,
      exec_env: exec_env
      # TODO: sub_state
    }
  end

  @doc """
    Message-call into an account. Transfer `value` wei from callers account to callees account then run the code in that account.

    ## Examples

        iex> account_map = %{
        ...>   <<0::160>> => %{balance: 100, nonce: 5, code: <<>>},
        ...>   <<1::160>> => %{balance: 100, nonce: 5, code: <<>>},
        ...>   <<2::160>> => %{balance: 100, nonce: 5, code: <<>>},
        ...> }
        iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(account_map)
        iex> exec_env = %EVM.ExecEnv{
        ...>   account_interface: account_interface,
        ...>   sender: <<0::160>>,
        ...>   address: <<0::160>>
        ...> }
        iex> machine_state = %EVM.MachineState{gas: 1000}
        iex> %{machine_state: machine_state, exec_env: exec_env} =
        ...> EVM.Operation.System.call([10, 1, 1, 0, 0, 0, 0],
        ...>   %{exec_env: exec_env, machine_state: machine_state})
        iex> EVM.Stack.peek(machine_state.stack)
        1
        iex> exec_env.account_interface
        ...>   |> EVM.Interface.AccountInterface.get_account_balance(<<0::160>>)
        99
        iex> exec_env.account_interface
        ...>   |> EVM.Interface.AccountInterface.get_account_balance(<<1::160>>)
        101
  """
  @spec call(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def call([call_gas, to, value, in_offset, in_size, out_offset, _out_size], %{
        exec_env: exec_env,
        machine_state: machine_state
      }) do
    to = Address.new(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)

    account_balance =
      AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    machine_code = AccountInterface.get_account_code(exec_env.account_interface, to)

    if call_gas <= account_balance && exec_env.stack_depth < EVM.Functions.max_stack_depth() do
      exec_env = ExecEnv.tranfer_wei_to(exec_env, to, value)

      {n_gas, _n_sub_state, n_exec_env, n_output} =
        EVM.VM.run(
          call_gas,
          Map.merge(exec_env, %{
            # a
            address: to,
            # s
            sender: exec_env.address,
            # d
            data: data,
            # v
            value_in_wei: value,
            # b
            machine_code: machine_code,
            # e
            stack_depth: exec_env.stack_depth + 1
          })
        )

      exec_env = %{exec_env | account_interface: n_exec_env.account_interface}
      # TODO: Set n_account_interface

      machine_state = EVM.Memory.write(machine_state, out_offset, n_output)
      machine_state = %{machine_state | gas: machine_state.gas + n_gas}
      # Return 1: 1 = success, 0 = failure
      # TODO Check if the call was actually successful
      machine_state = %{machine_state | stack: Stack.push(machine_state.stack, 1)}

      %{
        machine_state: machine_state,
        exec_env: exec_env
        # TODO: sub_state
      }
    else
      %{
        machine_state: %{machine_state | stack: Stack.push(machine_state.stack, 0)}
      }
    end
  end

  @spec callcode(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def callcode(
        [call_gas, _to, value, in_offset, in_size, out_offset, out_size],
        %{
          exec_env: exec_env,
          machine_state: _machine_state
        } = vm_map
      ) do
    call([call_gas, exec_env.address, value, in_offset, in_size, out_offset, out_size], vm_map)
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
    machine_state |> MachineState.maybe_set_active_words(EVM.Memory.get_active_words(mem_end))
  end

  @doc """
  Halt execution and register account for later deletion.

  ## Examples

      iex> address = 0x0000000000000000000000000000000000000001
      iex> suicide_address = 0x0000000000000000000000000000000000000001
      iex> account_map = %{address => %{balance: 5_000, nonce: 5}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(account_map)
      iex> account_interface = EVM.Operation.System.suicide([suicide_address], %{stack: [], exec_env: %EVM.ExecEnv{address: address, account_interface: account_interface} })[:exec_env].account_interface
      iex> account_interface |> EVM.Interface.AccountInterface.dump_storage |> Map.get(address)
      nil
  """
  @spec suicide(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def suicide([_suicide_address], %{exec_env: exec_env}) do
    %{exec_env: ExecEnv.suicide_account(exec_env)}
  end
end
