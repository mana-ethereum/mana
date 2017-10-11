defmodule Blockchain.Contract do
  @moduledoc """
  Defines functions on create and making message calls
  to contracts. The core of the module is to implement
  Λ and Θ, as defined in Eq.(70) and described in detail
  in sections 7 and 8 of the Yellow Paper.
  """

  alias Blockchain.Account
  alias Block.Header

  @doc """
  Creates a new contract, as defined in Section 7 Eq.(81) and Eq.(87) of the Yellow Paper as Λ.

  We are also inlining Eq.(97) and Eq.(98), I think.

  # TODO: Block header? "I_H has no special treatment and is determined from the blockchain"
  # TODO: Do we need to break this function up further?
  # TODO: Add rich tests in `contract_test.exs`

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:contract_create_test)
      iex> {state, _gas, _sub_state} = MerklePatriciaTree.Trie.new(db)
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 11, nonce: 5})
      ...> |> Blockchain.Contract.create_contract(<<0x10::160>>, <<0x10::160>>, 1000, 1, 5, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]), 5, %Block.Header{nonce: 1})
      {
        %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :contract_create_test}, root_hash: <<98, 127, 176, 34, 60, 87, 113, 153, 133, 112, 237, 229, 251, 94, 163, 145, 234, 68, 26, 244, 25, 19, 211, 192, 172, 75, 106, 198, 229, 248, 105, 39>>},
        976,
        %EVM.SubState{}
      }
      iex> Blockchain.Account.get_accounts(state, [<<0x10::160>>, Blockchain.Contract.new_contract_address(<<0x10::160>>, 5)])
      [%Blockchain.Account{balance: 6, nonce: 5}, %Blockchain.Account{balance: 5, code_hash: <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160, 162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>}]
      iex> Blockchain.Account.get_machine_code(state, Blockchain.Contract.new_contract_address(<<0x10::160>>, 5))
      {:ok, <<0x08::256>>}
      iex> MerklePatriciaTree.Trie.Inspector.all_keys(state) |> Enum.count
      3
  """
  @spec create_contract(EVM.state, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: {EVM.state, EVM.Gas.t, EVM.SubState.t}
  def create_contract(state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header) do

    sender_account = Account.get_account(state, sender)
    contract_address = new_contract_address(sender, sender_account.nonce)
    state_with_blank_contract = create_blank_contract(state, contract_address, sender, endowment)

    exec_env = create_contract_exec_env(
      contract_address,
      originator,
      gas_price,
      sender,
      endowment,
      init_code,
      stack_depth,
      block_header,
      state_with_blank_contract)

    {state_after_init, remaining_gas, accrued_sub_state, output} =
      EVM.VM.run(available_gas, exec_env)
      |> interpret_vm_result

    contract_creation_cost = get_contract_creation_cost(output)
    insufficient_gas_before_homestead = remaining_gas < contract_creation_cost and Header.is_before_homestead?(block_header)

    resultant_gas = cond do
      state_after_init == nil -> 0
      insufficient_gas_before_homestead -> remaining_gas
      true -> remaining_gas - contract_creation_cost
    end

    resultant_state = cond do
      state_after_init == nil -> state
      insufficient_gas_before_homestead -> state_after_init
      true ->
        state_after_init
        |> Account.put_code(contract_address, output)
    end

    {resultant_state, resultant_gas, accrued_sub_state}
  end

  @doc """
  Executes a message call to a contract, defiend in Section 8 Eq.(99) of the Yellow Paper as Θ.

  We are also inlining Eq.(105).

  TODO: Determine whether or not we should be passing in the block header directly.
  TODO: Add serious (less trivial) test cases in `contract_test.exs`

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:message_call_test)
      iex> {state, _gas, _sub_state, _output} = MerklePatriciaTree.Trie.new(db)
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 10})
      ...> |> Blockchain.Account.put_account(<<0x20::160>>, %Blockchain.Account{balance: 20})
      ...> |> Blockchain.Account.put_code(<<0x20::160>>, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]))
      ...> |> Blockchain.Contract.message_call(<<0x10::160>>, <<0x10::160>>, <<0x20::160>>, <<0x20::160>>, 1000, 1, 5, 5, <<1, 2, 3>>, 5, %Block.Header{nonce: 1})
      {
        %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :message_call_test}, root_hash: <<10, 196, 161, 81, 223, 4, 171, 127, 206, 82, 83, 156, 61, 5, 44, 225, 206, 88, 22, 193, 27, 83, 226, 3, 15, 254, 193, 75, 188, 50, 125, 104>>},
        976,
        %EVM.SubState{},
        <<0x08::256>>
      }
      iex> Blockchain.Account.get_accounts(state, [<<0x10::160>>, <<0x20::160>>])
      [%Blockchain.Account{balance: 5}, %Blockchain.Account{balance: 25, code_hash: <<135, 110, 129, 59, 111, 55, 97, 45, 238, 64, 115, 133, 37, 188, 196, 107, 160, 151, 31, 167, 249, 187, 243, 251, 173, 170, 244, 204, 78, 134, 208, 239>>}]
      iex> MerklePatriciaTree.Trie.Inspector.all_keys(state) |> Enum.count
      3
  """
  @spec message_call(EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header) do

    exec_fun = get_message_call_exec_fun(recipient)

    {:ok, machine_code} = Account.get_machine_code(state, contract) # note, this could fail if machine code is not in state

    state_initialized_for_message_call = initialize_message_call(state, sender, recipient, value)

    exec_env = create_message_call_exec_env(
      sender,
      originator,
      recipient,
      gas_price,
      apparent_value,
      data,
      stack_depth,
      machine_code,
      block_header,
      state_initialized_for_message_call)

    exec_fun.(available_gas, exec_env) |> interpret_vm_result
  end

  @doc """
  Determines the address of a new contract based on the sender and
  the sender's current nonce.

  This is defined as Eq.(82) in the Yellow Paper.

  Note: we should use the pre-incremented nonce when calling this function.

  ## Examples

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 1)
      <<82, 43, 50, 148, 230, 208, 106, 162, 90, 208, 241, 184, 137, 18, 66, 227, 53, 211, 180, 89>>

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 2)
      <<83, 91, 61, 122, 37, 47, 160, 52, 237, 113, 240, 197, 62, 192, 198, 247, 132, 203, 100, 225>>

      iex> Blockchain.Contract.new_contract_address(<<0x02::160>>, 3)
      <<30, 208, 147, 166, 216, 88, 183, 173, 67, 180, 70, 173, 88, 244, 201, 236, 9, 101, 145, 49>>
  """
  @spec new_contract_address(EVM.address, integer()) :: EVM.address
  def new_contract_address(sender, nonce) do
    [sender, nonce - 1]
      |> ExRLP.encode()
      |> BitHelper.kec()
      |> BitHelper.mask_bitstring(160)
  end

  @doc """
  Creates a blank contract prior to initialization code being run,
  as defined in Eq.(83), Eq.(84) and Eq.(85) of the Yellow Paper.

  We also indirectly cover Eq.(86)

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...> |> Blockchain.Contract.create_blank_contract(<<0x02::160>>, <<0x01::160>>, 6)
      ...> |> Blockchain.Account.get_accounts([<<0x01::160>>, <<0x02::160>>])
      [%Blockchain.Account{balance: 4}, %Blockchain.Account{balance: 6}]
  """
  @spec create_blank_contract(EVM.state, EVM.address, EVM.address, EVM.Wei.t) :: EVM.state
  def create_blank_contract(state, contract_address, sender, endowment) do
    Account.transfer!(state, sender, contract_address, endowment)
  end

  @doc """
  Initiates message call by transfering balance from sender to receiver.

  This covers Eq.(101), Eq.(102), Eq.(103) and Eq.(104) of the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      ...> |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{balance: 10})
      ...> |> Blockchain.Contract.initialize_message_call(<<0x01::160>>, <<0x02::160>>, 6)
      ...> |> Blockchain.Account.get_accounts([<<0x01::160>>, <<0x02::160>>])
      [%Blockchain.Account{balance: 4}, %Blockchain.Account{balance: 6}]
  """
  @spec initialize_message_call(EVM.state, EVM.address, EVM.address, EVM.Wei.t) :: EVM.state
  def initialize_message_call(state, sender, receiver, endowment) do
    Account.transfer!(state, sender, receiver, endowment)
  end

  @doc """
  Creates an execution environment for a create contract call.

  This is defined in Eq.(88), Eq.(89), Eq.(90), Eq.(91), Eq.(92),
  Eq.(93), Eq.(94) and Eq.(95) of the Yellow Paper.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:create_contract_exec_env)
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> Blockchain.Contract.create_contract_exec_env(<<0x01::160>>, <<0x02::160>>, 5, <<0x03::160>>, 6, <<1, 2, 3>>, 14, %Block.Header{nonce: 1}, state)
      %EVM.ExecEnv{
        address: <<0x01::160>>,
        originator: <<0x02::160>>,
        gas_price: 5,
        data: <<>>,
        sender: <<0x03::160>>,
        value_in_wei: 6,
        machine_code: <<1, 2, 3>>,
        stack_depth: 14,
        block_interface: %Blockchain.Interface.BlockInterface{block_header: %Block.Header{nonce: 1}, db: {MerklePatriciaTree.DB.ETS, :create_contract_exec_env}},
        account_interface: %Blockchain.Interface.AccountInterface{state: %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :create_contract_exec_env}, root_hash: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>}}
      }
  """
  @spec create_contract_exec_env(EVM.address, EVM.address, EVM.Wei.t, EVM.address, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t, EVM.state) :: EVM.ExecEnv.t
  def create_contract_exec_env(contract_address, originator, gas_price, sender, endowment, init_code, stack_depth, block_header, state) do
    %EVM.ExecEnv{
      address: contract_address,
      originator: originator,
      gas_price: gas_price,
      data: <<>>,
      sender: sender,
      value_in_wei: endowment,
      machine_code: init_code,
      stack_depth: stack_depth,
      block_interface: Blockchain.Interface.BlockInterface.new(block_header, state.db),
      account_interface: Blockchain.Interface.AccountInterface.new(state)
    }
  end

  @doc """
  Creates an execution environment for a message call.

  This is defined in Eq.(107), Eq.(108), Eq.(109), Eq.(110),
  Eq.(111), Eq.(112), Eq.(113) and Eq.(114) of the Yellow Paper.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db(:create_message_call_exec_env)
      iex> state = MerklePatriciaTree.Trie.new(db)
      iex> Blockchain.Contract.create_message_call_exec_env(<<0x01::160>>, <<0x02::160>>, <<0x03::160>>, 4, 5, <<1, 2, 3>>, 14, <<2, 3, 4>>, %Block.Header{nonce: 1}, state)
      %EVM.ExecEnv{
        address: <<0x03::160>>,
        originator: <<0x02::160>>,
        gas_price: 4,
        data: <<1, 2, 3>>,
        sender: <<0x01::160>>,
        value_in_wei: 5,
        machine_code: <<2, 3, 4>>,
        stack_depth: 14,
        block_interface: %Blockchain.Interface.BlockInterface{block_header: %Block.Header{nonce: 1}, db: {MerklePatriciaTree.DB.ETS, :create_message_call_exec_env}},
        account_interface: %Blockchain.Interface.AccountInterface{state: %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :create_message_call_exec_env}, root_hash: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>}}
      }
  """
  @spec create_message_call_exec_env(EVM.address, EVM.address, EVM.address, EVM.Wei.t, EVM.Wei.t, binary(), integer(), EVM.MachineCode.t, Header.t, EVM.state) :: EVM.ExecEnv.t
  def create_message_call_exec_env(sender, originator, recipient, gas_price, apparent_value, data, stack_depth, machine_code, block_header, state) do
    %EVM.ExecEnv{
      address: recipient,
      originator: originator,
      gas_price: gas_price,
      data: data,
      sender: sender,
      value_in_wei: apparent_value,
      machine_code: machine_code,
      stack_depth: stack_depth,
      block_interface: Blockchain.Interface.BlockInterface.new(block_header, state.db),
      account_interface: Blockchain.Interface.AccountInterface.new(state),
    }
  end

  @doc """
  Returns the additional cost after creating a new contract.

  This is defined as Eq.(96) of the Yellow Paper.

  # TODO: Implement and examples
  """
  @spec get_contract_creation_cost(binary()) :: EVM.Wei.t
  def get_contract_creation_cost(output) do
    0
  end

  @doc """
  Returns the given function to run given a contract address. This covers
  selecting a pre-defined function if specified. This is defined in Eq.(106)
  of the Yellow Paper.

  ## Examples

      iex> Blockchain.Contract.get_message_call_exec_fun(<<1::160>>)
      &EVM.Builtin.run_ecrec/2

      iex> Blockchain.Contract.get_message_call_exec_fun(<<2::160>>)
      &EVM.Builtin.run_sha256/2

      iex> Blockchain.Contract.get_message_call_exec_fun(<<3::160>>)
      &EVM.Builtin.run_rip160/2

      iex> Blockchain.Contract.get_message_call_exec_fun(<<4::160>>)
      &EVM.Builtin.run_id/2

      iex> Blockchain.Contract.get_message_call_exec_fun(<<5::160>>)
      &EVM.VM.run/2

      iex> Blockchain.Contract.get_message_call_exec_fun(<<6::160>>)
      &EVM.VM.run/2
  """
  @spec get_message_call_exec_fun(EVM.address) :: ( (EVM.Gas.t, EVM.ExecEnv.t) -> {EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output} )
  def get_message_call_exec_fun(recipient) do
    case :binary.decode_unsigned(recipient) do
      1 -> &EVM.Builtin.run_ecrec/2
      2 -> &EVM.Builtin.run_sha256/2
      3 -> &EVM.Builtin.run_rip160/2
      4 -> &EVM.Builtin.run_id/2
      _ -> &EVM.VM.run/2
    end
  end

  @spec interpret_vm_result({EVM.Gas.t, EVM.SubState.t, EVM.ExecEnv.t, EVM.VM.output}) :: {EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output}
  defp interpret_vm_result({gas, sub_state, exec_env, output}), do: {exec_env.account_interface.state, gas, sub_state, output}

end