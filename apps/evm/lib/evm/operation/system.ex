defmodule EVM.Operation.System do
  alias EVM.MachineState
  alias EVM.Interface.AccountInterface
  alias EVM.Interface.BlockInterface
  alias EVM.Interface.ContractInterface
  alias EVM.Helpers
  alias EVM.Stack

  @doc """
  Create a new account with associated code.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: 5_000, nonce: 5)
      iex> contract_interface = EVM.Interface.Mock.MockContractInterface.new(state, 500, nil, "output")
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, address: <<100::160>>, account_interface: account_interface, contract_interface: contract_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state, state: n_state} =
      ...>   EVM.Operation.System.create(
      ...>     [1_000, 5, 5],
      ...>     %{state: state, exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [100, 1], active_words: 1, memory: "________input"}
      iex> n_state == state
      true
  """
  @spec create(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def create([value, in_offset, in_size], %{state: state, exec_env: exec_env, machine_state: machine_state}) do

    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)
    account_balance = AccountInterface.get_account_balance(exec_env.account_interface, state, exec_env.address)
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed = value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth

    { state_with_nonce_updated, original_nonce } = if is_allowed do
      AccountInterface.increment_account_nonce(
        exec_env.account_interface,
        state,
        exec_env.address
      )
    else
      { nil, nil }
    end

    { n_state, n_gas, _n_sub_state } = if is_allowed do

      available_gas = Helpers.all_but_one_64th(machine_state.gas)

      ContractInterface.create_contract(
        exec_env.contract_interface,
        state_with_nonce_updated,      # state
        exec_env.address,              # sender
        exec_env.originator,           # originator
        available_gas,                 # available_gas
        exec_env.gas_price,            # gas_price
        value,                         # endowment
        data,                          # init_code
        exec_env.stack_depth + 1,      # stack_depth
        block_header)                  # block_header
    else
        { state, machine_state.gas, nil }
    end

    # Add back extra gas
    machine_state = %{machine_state | gas: machine_state.gas + n_gas}

    # Note if was exception halt or other failure on stack
    result = if is_allowed and not is_nil(n_state) do
      ContractInterface.new_contract_address(exec_env.contract_interface, exec_env.address, original_nonce) |> Helpers.wrap_address |> :binary.decode_unsigned
    else
      0
    end

    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, result)}

    %{
      state: n_state,
      machine_state: machine_state
      # TODO: sub_state
    }
  end

  @doc """
  For call: Message-call into an account.
  For call code: Message-call into this account with an alternative account's code.
  For delegate call: Message-call into this account with an alternative account's code, but persisting the current values for sender and value.

  ## Examples

      # CALL
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: 5_000)
      iex> contract_interface = EVM.Interface.Mock.MockContractInterface.new(state, 500, nil, "output")
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, account_interface: account_interface, contract_interface: contract_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state, state: n_state} =
      ...>   EVM.Operation.System.call(
      ...>     :call,
      ...>     [100, <<0x01::160>>, 1_000, 5, 5, 1, 6],
      ...>     %{state: state, exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input", pc: 0, previously_active_words: 1}
      iex> n_state == state
      true

      # CALLCODE
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: 5_000)
      iex> contract_interface = EVM.Interface.Mock.MockContractInterface.new(state, 500, nil, "output")
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, account_interface: account_interface, contract_interface: contract_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state, state: n_state} =
      ...>   EVM.Operation.System.call(
      ...>     :call_code,
      ...>     [100, <<0x01::160>>, 1_000, 5, 5, 1, 6],
      ...>     %{state: state, exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input", previously_active_words: 1}
      iex> n_state == state
      true

      # DELEGATECALL
      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{})
      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new(balance: 5_000)
      iex> contract_interface = EVM.Interface.Mock.MockContractInterface.new(state, 500, nil, "output")
      iex> exec_env = %EVM.ExecEnv{stack_depth: 0, account_interface: account_interface, contract_interface: contract_interface, block_interface: block_interface}
      iex> machine_state = %EVM.MachineState{gas: 300, stack: [1], memory: "________" <> "input"}
      iex> %{machine_state: n_machine_state, state: n_state} =
      ...>   EVM.Operation.System.call(
      ...>     :delegate_call,
      ...>     [100, <<0x01::160>>, 5, 5, 1, 6],
      ...>     %{state: state, exec_env: exec_env, machine_state: machine_state})
      iex> n_machine_state
      %EVM.MachineState{gas: 800, stack: [1, 1], active_words: 1, memory: "_output_input", previously_active_words: 1}
      iex> n_state == state
      true
  """
  @spec call(atom(), Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def call(:delegate_call, [call_gas, to, in_offset, in_size, out_offset, out_size], vm_map) do
    # pass 0 as `value` for delegate call
    call(:delegate_call, [call_gas, to, 0, in_offset, in_size, out_offset, out_size], vm_map)
  end

  def call(type, [call_gas, to, value, in_offset, in_size, out_offset, out_size], %{state: state, exec_env: exec_env, machine_state: machine_state}) when type in [:call, :call_code, :delegate_call] do

    to_addr = Helpers.wrap_address(to)
    {data, machine_state} = EVM.Memory.read(machine_state, in_offset, in_size)
    account_balance = AccountInterface.get_account_balance(exec_env.account_interface, state, exec_env.address)
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    is_allowed = value <= account_balance and exec_env.stack_depth < EVM.Functions.max_stack_depth

    recipient = if type == :call_code || type == :delegate_call, do: exec_env.address, else: to_addr
    apparent_value = if type == :delegate_call, do: exec_env.value_in_wei, else: value

    { n_state, n_gas, _n_sub_state, n_output } = if is_allowed do
      ContractInterface.message_call(
        exec_env.contract_interface,
        state,                     # state
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
        { state, call_gas, nil, <<>> }
    end

    # Write the output, bounded by specified size
    final_output = if byte_size(n_output) > out_size do
      :binary.part(n_output, 0, out_size)
    else
      n_output
    end

    machine_state = EVM.Memory.write(machine_state, out_offset, final_output)

    # Add back extra gas
    machine_state = %{machine_state | gas: machine_state.gas + n_gas}

    # Note if was exception halt or other failure on stack
    was_successful = if is_allowed and not is_nil(n_state), do: 1, else: 0 |> Helpers.wrap_int
    machine_state = %{machine_state | stack: Stack.push(machine_state.stack, was_successful)}

    %{
      state: n_state,
      machine_state: machine_state
      # TODO: sub_state
    }
  end

  @doc """
  Halt execution returning output data,

  ## Examples

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 0}})
      %EVM.MachineState{active_words: 2}

      iex> EVM.Operation.System.return([5, 33], %{machine_state: %EVM.MachineState{active_words: 5}})
      %EVM.MachineState{active_words: 5, previously_active_words: 5}
  """
  @spec return(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def return([_mem_start, mem_end], %{machine_state: machine_state}) do
    # We may have to bump up number of active words
    machine_state |> MachineState.maybe_set_active_words(EVM.Memory.get_active_words(mem_end))
  end

  @doc """
  Halt execution and register account for later deletion.

  TODO: Implement opcode

  ## Examples

      iex> EVM.Operation.System.suicide([], %{stack: []})
      :unimplemented
  """
  @spec suicide(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def suicide(_args, %{stack: _stack}) do
    :unimplemented
  end
end
