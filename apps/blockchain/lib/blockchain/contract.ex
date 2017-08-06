defmodule Blockchain.Contract do
  @moduledoc """
  Defines functions on create and making message calls
  to contracts. The core of the module is to implement
  Λ and Θ, as defined in Eq.(70) and described in detail
  in sections 7 and 8 of the Yellow Paper.
  """

  alias Blockchain.Account
  alias Blockchain.Block.Header

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
      ...> |> Blockchain.Contract.create_contract(<<0x10::160>>, <<0x10::160>>, 1000, 1, 5, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return]), 5, %Blockchain.Block.Header{nonce: 1})
      {
        %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :contract_create_test}, root_hash: <<147, 69, 180, 75, 134, 172, 4, 139, 196, 40, 253, 92, 248, 87, 51, 88, 182, 152, 139, 13, 235, 25, 34, 156, 93, 145, 30, 170, 172, 24, 93, 4>>},
        1000,
        %EVM.SubState{}
      }
      iex> Blockchain.Account.get_accounts(state, [<<0x10::160>>, Blockchain.Contract.new_contract_address(<<0x10::160>>, 5)])
      [%Blockchain.Account{balance: 6, nonce: 5}, %Blockchain.Account{balance: 5, code_hash: <<184, 49, 71, 53, 90, 147, 31, 209, 13, 252, 14, 242, 188, 146, 213, 98, 3, 169, 138, 178, 91, 23, 65, 191, 149, 7, 79, 68, 207, 121, 218, 225>>}]
      iex> Blockchain.Account.get_machine_code(state, Blockchain.Contract.new_contract_address(<<0x10::160>>, 5))
      {:ok, <<0x08::256>>}
      iex> MerklePatriciaTree.Trie.Inspector.all_keys(state)
      [
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16>>,
        <<184, 49, 71, 53, 90, 147, 31, 209, 13, 252, 14, 242, 188, 146, 213, 98, 3, 169, 138, 178, 91, 23, 65, 191, 149, 7, 79, 68, 207, 121, 218, 225>>,
        <<215, 103, 82, 153, 30, 215, 126, 236, 249, 242, 4, 46, 12, 67, 179, 240, 206, 97, 155, 241>>
      ]
  """
  @spec create_contract(EVM.state, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: {EVM.state, EVM.Gas.t, EVM.SubState.t}
  def create_contract(state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header) do

    sender_account = Account.get_account(state, sender)
    contract_address = new_contract_address(sender, sender_account.nonce)

    exec_env = create_contract_exec_env(
      contract_address,
      originator,
      gas_price,
      sender,
      endowment,
      init_code,
      stack_depth,
      block_header)

    {state_after_init, remaining_gas, accrued_sub_state, output} =
      state
      |> create_blank_contract(contract_address, sender, endowment)
      |> EVM.VM.run(available_gas, exec_env)

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
      ...> |> Blockchain.Account.put_code(<<0x20::160>>, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return]))
      ...> |> Blockchain.Contract.message_call(<<0x10::160>>, <<0x10::160>>, <<0x20::160>>, <<0x20::160>>, 1000, 1, 5, 5, <<1, 2, 3>>, 5, %Blockchain.Block.Header{nonce: 1})
      {
        %MerklePatriciaTree.Trie{db: {MerklePatriciaTree.DB.ETS, :message_call_test}, root_hash: <<167, 171, 171, 106, 158, 187, 23, 240, 91, 213, 210, 27, 151, 116, 57, 79, 97, 110, 201, 73, 204, 180, 114, 123, 138, 253, 156, 185, 239, 181, 117, 194>>},
        1000,
        %EVM.SubState{},
        <<0x08::256>>
      }
      iex> Blockchain.Account.get_accounts(state, [<<0x10::160>>, <<0x20::160>>])
      [%Blockchain.Account{balance: 5}, %Blockchain.Account{balance: 25, code_hash: <<247, 60, 39, 205, 253, 89, 146, 143, 219, 173, 26, 213, 173, 221, 39, 44, 111, 59, 34, 217, 228, 91, 21, 167, 59, 107, 79, 33, 90, 183, 135, 213>>}]
      iex> MerklePatriciaTree.Trie.Inspector.all_keys(state)
      [
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16>>,
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32>>,
        <<247, 60, 39, 205, 253, 89, 146, 143, 219, 173, 26, 213, 173, 221, 39, 44, 111, 59, 34, 217, 228, 91, 21, 167, 59, 107, 79, 33, 90, 183, 135, 213>> # this must be a sub-tree
      ]
  """
  @spec message_call(EVM.state, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header) do

    exec_fun = get_message_call_exec_fun(recipient)

    {:ok, machine_code} = Account.get_machine_code(state, contract) # note, this could fail if machine code is not in state

    exec_env = create_message_call_exec_env(
      sender,
      originator,
      recipient,
      gas_price,
      apparent_value,
      data,
      stack_depth,
      machine_code,
      block_header)

    state
      |> initialize_message_call(sender, recipient, value)
      |> exec_fun.(available_gas, exec_env)
  end

  @doc """
  Determines the address of a new contract based on the sender and
  the sender's current nonce.

  This is defined as Eq.(82) in the Yellow Paper.

  Note: we should use the pre-incremented nonce when calling this function.

  ## Examples

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 1)
      <<226, 9, 113, 163, 97, 244, 118, 145, 234, 155, 80, 129, 216, 104, 110, 120, 69, 35, 207, 135>>

      iex> Blockchain.Contract.new_contract_address(<<0x01::160>>, 2)
      <<119, 28, 153, 224, 10, 74, 14, 123, 121, 42, 82, 110, 145, 237,
        185, 6, 155, 63, 134, 131>>

      iex> Blockchain.Contract.new_contract_address(<<0x02::160>>, 3)
      <<168, 90, 253, 87, 136, 227, 10, 147, 161, 54, 235, 217, 223, 39,
        93, 173, 120, 143, 109, 210>>
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

      iex> Blockchain.Contract.create_contract_exec_env(<<0x01::160>>, <<0x02::160>>, 5, <<0x03::160>>, 6, <<1, 2, 3>>, 14, %Blockchain.Block.Header{nonce: 1})
      %EVM.ExecEnv{
        address: <<0x01::160>>,
        originator: <<0x02::160>>,
        gas_price: 5,
        data: <<>>,
        sender: <<0x03::160>>,
        value_in_wei: 6,
        machine_code: <<1, 2, 3>>,
        block_header: %Blockchain.Block.Header{nonce: 1},
        stack_depth: 14,
      }
  """
  @spec create_contract_exec_env(EVM.address, EVM.address, EVM.Wei.t, EVM.address, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: EVM.ExecEnv.t
  def create_contract_exec_env(contract_address, originator, gas_price, sender, endowment, init_code, stack_depth, block_header) do
    %EVM.ExecEnv{
      address: contract_address,
      originator: originator,
      gas_price: gas_price,
      data: <<>>,
      sender: sender,
      value_in_wei: endowment,
      machine_code: init_code,
      block_header: block_header,
      stack_depth: stack_depth,
    }
  end

  @doc """
  Creates an execution environment for a message call.

  This is defined in Eq.(107), Eq.(108), Eq.(109), Eq.(110),
  Eq.(111), Eq.(112), Eq.(113) and Eq.(114) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Contract.create_message_call_exec_env(<<0x01::160>>, <<0x02::160>>, <<0x03::160>>, 4, 5, <<1, 2, 3>>, 14, <<2, 3, 4>>, %Blockchain.Block.Header{nonce: 1})
      %EVM.ExecEnv{
        address: <<0x03::160>>,
        originator: <<0x02::160>>,
        gas_price: 4,
        data: <<1, 2, 3>>,
        sender: <<0x01::160>>,
        value_in_wei: 5,
        machine_code: <<2, 3, 4>>,
        block_header: %Blockchain.Block.Header{nonce: 1},
        stack_depth: 14,
      }
  """
  @spec create_message_call_exec_env(EVM.address, EVM.address, EVM.address, EVM.Wei.t, EVM.Wei.t, binary(), integer(), EVM.MachineCode.t, Header.t) :: EVM.ExecEnv.t
  def create_message_call_exec_env(sender, originator, recipient, gas_price, apparent_value, data, stack_depth, machine_code, block_header) do
    %EVM.ExecEnv{
      address: recipient,
      originator: originator,
      gas_price: gas_price,
      data: data,
      sender: sender,
      value_in_wei: apparent_value,
      machine_code: machine_code,
      block_header: block_header,
      stack_depth: stack_depth
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
      &EVM.Builtin.run_ecrec/3

      iex> Blockchain.Contract.get_message_call_exec_fun(<<2::160>>)
      &EVM.Builtin.run_sha256/3

      iex> Blockchain.Contract.get_message_call_exec_fun(<<3::160>>)
      &EVM.Builtin.run_rip160/3

      iex> Blockchain.Contract.get_message_call_exec_fun(<<4::160>>)
      &EVM.Builtin.run_id/3

      iex> Blockchain.Contract.get_message_call_exec_fun(<<5::160>>)
      &EVM.VM.run/3

      iex> Blockchain.Contract.get_message_call_exec_fun(<<6::160>>)
      &EVM.VM.run/3
  """
  @spec get_message_call_exec_fun(EVM.address) :: ( (EVM.state, EVM.Gas.t, EVM.ExecEnv.t) -> {EVM.state, EVM.Gas.t, EVM.SubState.t, EVM.VM.output} )
  def get_message_call_exec_fun(recipient) do
    case :binary.decode_unsigned(recipient) do
      1 -> &EVM.Builtin.run_ecrec/3
      2 -> &EVM.Builtin.run_sha256/3
      3 -> &EVM.Builtin.run_rip160/3
      4 -> &EVM.Builtin.run_id/3
      _ -> &EVM.VM.run/3
    end
  end

end