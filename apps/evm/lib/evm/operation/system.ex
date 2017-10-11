defmodule EVM.Operation.System do
  alias EVM.MachineState
  alias EVM.ExecEnv
  alias EVM.Interface.AccountInterface
  alias EVM.Interface.BlockInterface
  alias EVM.Helpers
  alias EVM.Stack

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
      %EVM.MachineState{gas: 800, stack: [EVM.Helpers.left_pad_bytes(100, 20), 1], active_words: 1, memory: "________input"}
  """
  @spec create(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def create([value, in_offset, in_size], %{exec_env: exec_env, machine_state: machine_state}) do

    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)
    account_balance = AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed = value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth

    { updated_account_interface, n_gas, _n_sub_state } = if is_allowed do

      available_gas = Helpers.all_but_one_64th(machine_state.gas)

      AccountInterface.create_contract(
        exec_env.account_interface,
        exec_env.address,              # sender
        exec_env.originator,           # originator
        available_gas,                 # available_gas
        exec_env.gas_price,            # gas_price
        value,                         # endowment
        data,                          # init_code
        exec_env.stack_depth + 1,      # stack_depth
        block_header)                  # block_header
    else
        { exec_env.account_interface, machine_state.gas, nil }
    end

    # Add back extra gas
    machine_state = %{machine_state | gas: machine_state.gas + n_gas}

    # Note if was exception halt or other failure on stack
    result = if is_allowed do
      AccountInterface.new_contract_address(updated_account_interface, exec_env.address, 0) |> Helpers.wrap_address
    else
      0
    end

    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, result)}
    exec_env = %{ exec_env | account_interface: updated_account_interface }

    %{
      machine_state: machine_state,
      exec_env: exec_env
      # TODO: sub_state
    }
  end

  @doc """
  For call: Message-call into an account.
  For call code: Message-call into this account with an alternative account's code.
  For delegate call: Message-call into this account with an alternative account's code, but persisting the current values for sender and value.

  ## Examples

      # CALL
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_map = %{<<0::160>> => %{balance: 5_000, nonce: 5}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(%{account_map: account_map}, %{gas: 500, sub_state: nil, output: "output"})
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, address: <<0::160>>, account_interface: account_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state} =
      ...>   EVM.Operation.System.call(
      ...>     :call,
      ...>     [100, <<0x01::160>>, 1_000, 5, 5, 1, 6],
      ...>     %{exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input", program_counter: 0}

      # CALLCODE
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_map = %{<<0::160>> => %{balance: 5_000}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(account_map, %{gas: 500, sub_state: nil, output: "output"})
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, address: <<0::160>>, account_interface: account_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state} =
      ...>   EVM.Operation.System.call(
      ...>     :call_code,
      ...>     [100, <<0x01::160>>, 1_000, 5, 5, 1, 6],
      ...>     %{exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input"}

      # DELEGATECALL
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_map = %{<<0::160>> => %{balance: 5_000}}
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(account_map, %{gas: 500, sub_state: nil, output: "output"})
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, address: <<0::160>>, account_interface: account_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state} =
      ...>   EVM.Operation.System.call(
      ...>     :delegate_call,
      ...>     [100, <<0x01::160>>, 5, 5, 1, 6],
      ...>     %{exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input"}
  """
  @spec call(atom(), Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def call(:delegate_call, [call_gas, to, in_offset, in_size, out_offset, out_size], vm_map) do
    # pass 0 as `value` for delegate call
    call(:delegate_call, [call_gas, to, 0, in_offset, in_size, out_offset, out_size], vm_map)
  end

  def call(type, [call_gas, to, value, in_offset, in_size, out_offset, out_size], %{exec_env: exec_env, machine_state: machine_state}) when type in [:call, :call_code, :delegate_call] do

    to_addr = Helpers.wrap_address(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)
    account_balance = AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed = value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth

    recipient = if type == :call_code || type == :delegate_call, do: exec_env.address, else: to_addr
    apparent_value = if type == :delegate_call, do: exec_env.value_in_wei, else: value

    { n_account_interface, n_gas, _n_sub_state, n_output } = if is_allowed do
      AccountInterface.message_call(
        exec_env.account_interface,
        exec_env.address,          # sender
        exec_env.originator,       # originator
        recipient,                 # recipient
        to_addr,                   # contract
        call_gas,                  # available_gas # TODO: Call gas?
        exec_env.gas_price,        # gas_price
        value,                     # value
        apparent_value,            # apparent_value
        data,                      # data
        exec_env.stack_depth + 1,  # stack_depth
        block_header)              # block_header
    else
        # TODO: What are we supposed to put as output?
        { exec_env.account_interface, call_gas, nil, <<>> }
    end

    # Write the output, bounded by specified size
    final_output = if byte_size(n_output) > out_size do
      :binary.part(n_output, 0, out_size)
    else
      n_output
    end

    machine_state = EVM.Memory.write(machine_state, out_offset, final_output)
    exec_env = %{ exec_env | account_interface: n_account_interface }

    # Add back extra gas
    machine_state = %{machine_state | gas: machine_state.gas + n_gas}

    # Note if was exception halt or other failure on stack
    was_successful = if is_allowed, do: 1, else: 0 |> Helpers.wrap_int
    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, was_successful)}

    %{
      machine_state: machine_state,
      exec_env: exec_env
      # TODO: sub_state
    }
  end

  @spec call(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def call([call_gas, to, value, in_offset, in_size, out_offset, _out_size], %{exec_env: exec_env, machine_state: machine_state}) do

    { contract_code, machine_state } = EVM.Memory.read(machine_state, in_offset, in_size)
    account_balance = AccountInterface.get_account_balance(exec_env.account_interface, exec_env.address)

    if call_gas <= account_balance && exec_env.stack_depth < EVM.Functions.max_stack_depth do

      { _n_state, n_gas, _n_sub_state, n_output } = message_call(
        exec_env.account_interface,
        exec_env.address,          # sender
        exec_env.originator,       # originator
        exec_env.address,          # recipient
        to,                        # contract
        call_gas,                  # available_gas # TODO: Call gas?
        exec_env.gas_price,        # gas_price
        value,                     # value
        exec_env.value_in_wei,     # apparent_value
        contract_code,             # data
        exec_env.stack_depth)      # stack_depth

      # TODO: Set n_account_interface

      machine_state = EVM.Memory.write(machine_state, out_offset, n_output)
      machine_state = %{machine_state | gas: machine_state.gas + n_gas}
      # Return 1: 1 = success, 0 = failure
      # TODO Check if the call was actually successful
      machine_state = %{machine_state | stack: Stack.push(machine_state.stack, 1)}

      %{
        machine_state: machine_state
        # TODO: sub_state
      }
    else
      %{machine_state | stack: Stack.push(machine_state.stack, 0)}
    end
  end

  @spec message_call(EVM.Interface.AccountInterface.t, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer()) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  defp message_call(_mock_account_interface, _sender, _originator, _recipient, _contract, available_gas, _gas_price, _value, _apparent_value, data, stack_depth) do
    EVM.VM.run(
      available_gas,
      %EVM.ExecEnv{
        machine_code: data,
        stack_depth: stack_depth + 1,
      }
    )
  end

  @doc """
  Halt execution returning output data,

  ## Examples

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 0}})
      %EVM.MachineState{active_words: 2}

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 5}})
      %EVM.MachineState{active_words: 5}
  """
  @spec return(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec suicide(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def suicide([_suicide_address], %{exec_env: exec_env}) do
    %{exec_env: ExecEnv.suicide_account(exec_env)}
  end
end
