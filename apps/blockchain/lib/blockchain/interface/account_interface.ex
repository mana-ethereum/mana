defmodule Blockchain.Interface.AccountInterface do
  @moduledoc """
  Defines an interface for methods to interact with contracts and accounts.
  """

  @type t :: %__MODULE__{
    state: EVM.state
  }

  defstruct [
    :state
  ]

  @doc """
  Returns a new account interface.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:account_interface_new))
      iex> Blockchain.Interface.AccountInterface.new(state)
      %Blockchain.Interface.AccountInterface{
        state: %MerklePatriciaTree.Trie{
          db: { MerklePatriciaTree.DB.ETS, :account_interface_new },
          root_hash: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
        }
      }
  """
  @spec new(EVM.state) :: t
  def new(state) do
    %__MODULE__{
      state: state
    }
  end
end

defimpl EVM.Interface.AccountInterface, for: Blockchain.Interface.AccountInterface do

  @doc """
  Given an account interface and an address, returns the balance at that address.

  Note, if the account is nil (doesn't exist), we return nil.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_account_balance(<<1::160>>)
      5

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_account_balance(<<2::160>>)
      nil
  """
  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(account_interface, address) do
    case Blockchain.Account.get_account(account_interface.state, address) do
      nil -> nil
      account -> account.balance
    end
  end

  @doc """
  Given an account interface and an address, returns the code stored at given address.

  Note, if the account is nil (doesn't exist), we return nil.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_code(<<1::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_account_code(<<1::160>>)
      <<1, 2, 3>>

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_code(<<1::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_account_code(<<2::160>>)
      <<>>
  """
  @spec get_account_code(EVM.Interface.AccountInterface.t, EVM.address) :: nil | binary()
  def get_account_code(account_interface, address) do
    case Blockchain.Account.get_machine_code(account_interface.state, address) do
      {:ok, machine_code} -> machine_code
      :not_found -> nil
    end
  end

  @doc """
  Given an account interface and an address, increments the nonce on the account,
  returning both a new `AccountInterface` and the previous nonce value.

  ## Examples

      iex> {account_interface, nonce} =
      ...> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.increment_account_nonce(<<1::160>>)
      iex> nonce
      0
      iex> {_, nonce_2} = EVM.Interface.AccountInterface.increment_account_nonce(account_interface, <<1::160>>)
      iex> nonce_2
      1
  """
  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: { EVM.Interface.AccountInterface.t, integer() }
  def increment_account_nonce(account_interface, address) do
    { state, before_acct, _after_acct } = Blockchain.Account.increment_nonce(account_interface.state, address, true)

    { Map.put(account_interface, :state, state), before_acct.nonce }
  end

  @doc """
  Given an account interface, an account address and a key, returns the value of
  that given in the account's personal storage.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_storage(<<1::160>>, 5)
      {:ok, 6}

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_storage(<<1::160>>, 6)
      :key_not_found

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.get_storage(<<2::160>>, 5)
      :account_not_found
  """
  @spec get_storage(EVM.Interface.AccountInterface.t, EVM.address, integer()) :: {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(account_interface, address, key) do
    Blockchain.Account.get_storage(account_interface.state, address, key)
  end

  @spec account_exists?(EVM.Interface.AccountInterface.t, EVM.address) :: boolean()
  def account_exists?(account_interface, address) do
    !!Blockchain.Account.get_account(account_interface.state, address)
  end

  @doc """
  Given an account interface, an account address, a key and a value, puts the
  value at that key location, overwriting any previous value.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.put_storage(<<1::160>>, 5, 6)
      ...> |> EVM.Interface.AccountInterface.get_storage(<<1::160>>, 5)
      {:ok, 6}

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.put_storage(<<1::160>>, 5, 6)
      ...> |> EVM.Interface.AccountInterface.get_storage(<<1::160>>, 6)
      :key_not_found

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.put_storage(<<1::160>>, 5, 6)
      ...> |> EVM.Interface.AccountInterface.get_storage(<<2::160>>, 5)
      :account_not_found
  """
  @spec put_storage(EVM.Interface.AccountInterface.t, EVM.address, integer(), integer()) :: EVM.Interface.AccountInterface.t
  def put_storage(account_interface, address, key, value) do
    updated_state = Blockchain.Account.put_storage(account_interface.state, address, key, value)

    %{account_interface | state: updated_state}
  end

  @doc """
  Suicides an account (err.. SELFDESTRUCT is the new word). This removes any trace
  of the account from the system.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.suicide_account(<<1::160>>)
      ...> |> EVM.Interface.AccountInterface.get_account_balance(<<1::160>>)
      nil

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.suicide_account(<<2::160>>)
      ...> |> EVM.Interface.AccountInterface.get_account_balance(<<1::160>>)
      5
  """
  @spec suicide_account(EVM.Interface.AccountInterface.t, EVM.address) :: EVM.Interface.AccountInterface.t
  def suicide_account(account_interface, address) do
    updated_state = Blockchain.Account.del_account(account_interface.state, address)

    %{account_interface | state: updated_state}
  end

  @doc """
  Given an account interface, dumps all key-value pairs. This should only be used
  for testing and debugging.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> MerklePatriciaTree.Trie.update(<<5>>, <<6>>)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.dump_storage()
      %{<<5>> => <<6>>}
  """
  @spec dump_storage(EVM.Interface.AccountInterface.t) :: %{ EVM.address => EVM.val }
  def dump_storage(account_interface) do
    MerklePatriciaTree.Trie.Inspector.all_values(account_interface.state) |> Enum.into(%{})
  end

  @doc """
  Runs a complete message call function, returning a new account interface,
  gas, sub state and output.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> {account_interface, _gas, _sub_state, _output} = MerklePatriciaTree.Trie.new(db)
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 10})
      ...> |> Blockchain.Account.put_account(<<0x20::160>>, %Blockchain.Account{balance: 20})
      ...> |> Blockchain.Account.put_code(<<0x20::160>>, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]))
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.message_call(<<0x10::160>>, <<0x10::160>>, <<0x20::160>>, <<0x20::160>>, 1000, 1, 5, 5, <<1, 2, 3>>, 5, %Block.Header{nonce: 1})
      iex> account_interface.state.root_hash
      <<163, 151, 95, 0, 149, 63, 81, 220, 74, 101, 219, 175, 240, 97, 153, 167, 249, 229, 144, 75, 101, 233, 126, 177, 8, 188, 105, 165, 28, 248, 67, 156>>
  """
  @spec message_call(EVM.Interface.AccountInterface.t, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.Interface.AccountInterface.t, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(account_interface, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header) do
    { state, gas, sub_state, output } = Blockchain.Contract.message_call(account_interface.state, sender, originator, recipient, contract, available_gas, gas_price, value, apparent_value, data, stack_depth, block_header)

    { Map.put(account_interface, :state, state), gas, sub_state, output }
  end

  @doc """
  Creates a new contract on the blockchain.

  ## Examples

      iex> {account_interface, _gas, _sub_state} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 11, nonce: 5})
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.create_contract(<<0x10::160>>, <<0x10::160>>, 1000, 1, 5, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]), 5, %Block.Header{nonce: 1})
      iex> account_interface.state.root_hash
      <<9, 235, 32, 146, 153, 242, 209, 192, 224, 61, 214, 174, 48, 24, 148, 28, 51, 254, 7, 82, 58, 82, 220, 157, 29, 159, 203, 51, 52, 240, 37, 122>>
  """
  @spec create_contract(EVM.Interface.AccountInterface.t, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { EVM.Interface.AccountInterface.t, EVM.Gas.t, EVM.SubState.t }
  def create_contract(account_interface, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header) do
    { state, gas, sub_state } = Blockchain.Contract.create_contract(account_interface.state, sender, originator, available_gas, gas_price, endowment, init_code, stack_depth, block_header)

    { Map.put(account_interface, :state, state), gas, sub_state }
  end

  @doc """
  Determines the address of a new contract based on the sender and
  the sender's current nonce.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.new_contract_address(<<0x01::160>>, 1)
      <<82, 43, 50, 148, 230, 208, 106, 162, 90, 208, 241, 184, 137, 18, 66, 227, 53, 211, 180, 89>>
  """
  @spec new_contract_address(EVM.Interface.AccountInterface.t, EVM.address, integer()) :: EVM.address
  def new_contract_address(_account_interface, address, nonce) do
    Blockchain.Contract.new_contract_address(address, nonce)
  end

end
