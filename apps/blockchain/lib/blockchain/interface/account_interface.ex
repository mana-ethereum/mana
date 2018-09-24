defmodule Blockchain.Interface.AccountInterface do
  @moduledoc """
  Defines an interface for methods to interact with contracts and accounts.
  """
  alias Blockchain.Interface.AccountInterface.Cache

  @type t :: %__MODULE__{
          state: EVM.state(),
          cache: Cache.t()
        }

  defstruct [
    :state,
    :cache
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
        },
        cache: %Blockchain.Interface.AccountInterface.Cache{cache: %{}}
      }
  """
  @spec new(EVM.state(), Cache.t()) :: t
  def new(state, cache \\ %Cache{}) do
    %__MODULE__{
      state: state,
      cache: cache
    }
  end

  @spec commit_storage(t()) :: EVM.state()
  def commit_storage(account_interface) do
    Cache.commit(account_interface.cache, account_interface.state)
  end
end

defimpl EVM.Interface.AccountInterface, for: Blockchain.Interface.AccountInterface do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Contract}
  alias EVM.Interface.AccountInterface
  alias Blockchain.Interface.AccountInterface.Cache

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
  @spec get_account_balance(AccountInterface.t(), EVM.address()) :: nil | EVM.Wei.t()
  def get_account_balance(account_interface, evm_address) do
    address = Account.Address.from(evm_address)

    case Account.get_account(account_interface.state, address) do
      nil -> nil
      account -> account.balance
    end
  end

  @spec add_wei(AccountInterface.t(), EVM.address(), integer()) :: AccountInterface.t()
  def add_wei(account_interface, evm_address, value) do
    address = Account.Address.from(evm_address)

    state = Account.add_wei(account_interface.state, address, value)

    Map.put(account_interface, :state, state)
  end

  @spec transfer(AccountInterface.t(), EVM.address(), EVM.address(), integer()) ::
          AccountInterface.t()
  def transfer(account_interface, evm_from, evm_to, value) do
    from = Account.Address.from(evm_from)
    to = Account.Address.from(evm_to)
    {:ok, state} = Account.transfer(account_interface.state, from, to, value)

    Map.put(account_interface, :state, state)
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
  @spec get_account_code(AccountInterface.t(), EVM.address()) :: nil | binary()
  def get_account_code(account_interface, evm_address) do
    address = Account.Address.from(evm_address)

    case Account.get_machine_code(account_interface.state, address) do
      {:ok, machine_code} -> machine_code
      :not_found -> nil
    end
  end

  @spec get_account_code_hash(AccountInterface.t(), EVM.address()) :: binary() | nil
  def get_account_code_hash(account_interface, address) do
    account = Account.get_account(account_interface.state, address)

    unless is_nil(account), do: account.code_hash
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
  @spec increment_account_nonce(AccountInterface.t(), EVM.address()) ::
          {AccountInterface.t(), integer()}
  def increment_account_nonce(account_interface, evm_address) do
    address = Account.Address.from(evm_address)

    {state, before_acct, _after_acct} =
      Account.increment_nonce(account_interface.state, address, true)

    {Map.put(account_interface, :state, state), before_acct.nonce}
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
  @spec get_storage(AccountInterface.t(), EVM.address(), integer()) ::
          {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(account_interface, evm_address, key) do
    address = Account.Address.from(evm_address)
    cached_value = Cache.current_value(account_interface.cache, address, key)

    case cached_value do
      nil -> Account.get_storage(account_interface.state, address, key)
      :deleted -> :key_not_found
      _ -> {:ok, cached_value}
    end
  end

  @spec get_initial_storage(AccountInterface.t(), EVM.address(), integer()) ::
          {:ok, integer()} | :account_not_found | :key_not_found
  def get_initial_storage(account_interface, evm_address, key) do
    address = Account.Address.from(evm_address)
    cached_value = Cache.initial_value(account_interface.cache, address, key)

    case cached_value do
      nil -> Account.get_storage(account_interface.state, address, key)
      :deleted -> :key_not_found
      _ -> {:ok, cached_value}
    end
  end

  @spec account_exists?(AccountInterface.t(), EVM.address()) :: boolean()
  def account_exists?(account_interface, evm_address) do
    address = Account.Address.from(evm_address)
    account = Account.get_account(account_interface.state, address)

    !is_nil(account)
  end

  @spec empty_account?(AccountInterface.t(), EVM.address()) :: boolean()
  def empty_account?(account_interface, evm_address) do
    address = Account.Address.from(evm_address)
    account = Account.get_account(account_interface.state, address)

    !is_nil(account) && Account.empty?(account)
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
      :account_not_found
  """
  @spec put_storage(AccountInterface.t(), EVM.address(), integer(), integer()) ::
          AccountInterface.t()
  def put_storage(account_interface, evm_address, key, value) do
    address = Account.Address.from(evm_address)

    if Account.get_account(account_interface.state, address) do
      updated_cache = Cache.update_current_value(account_interface.cache, address, key, value)

      %{account_interface | cache: updated_cache}
    else
      account_interface
    end
  end

  @spec remove_storage(AccountInterface.t(), EVM.address(), integer()) :: AccountInterface.t()
  def remove_storage(account_interface, evm_address, key) do
    address = Account.Address.from(evm_address)

    if Account.get_account(account_interface.state, address) do
      updated_cache = Cache.remove_current_value(account_interface.cache, address, key)

      %{account_interface | cache: updated_cache}
    else
      account_interface
    end
  end

  @doc """
  Given an account interface and an address, returns the nonce at that address.

  ## Examples

      iex> account_interface =
      ...> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Interface.AccountInterface.new()
      iex> EVM.Interface.AccountInterface.get_account_nonce(account_interface, <<1::160>>)
      0
      iex> {account_interface, _nonce} =
      ...> EVM.Interface.AccountInterface.increment_account_nonce(account_interface, <<1::160>>)
      iex> EVM.Interface.AccountInterface.get_account_nonce(account_interface, <<1::160>>)
      1
  """
  @spec get_account_nonce(AccountInterface.t(), EVM.address()) :: integer() | nil
  def get_account_nonce(account_interface, evm_address) do
    address = Account.Address.from(evm_address)
    account = Account.get_account(account_interface.state, address)
    if account, do: account.nonce, else: nil
  end

  @doc """
  Given an account interface, dumps all key-value pairs.
  This should only be used for testing and debugging.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> MerklePatriciaTree.Trie.update(<<5>>, <<6>>)
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.dump_storage()
      %{<<5>> => <<6>>}
  """
  @spec dump_storage(AccountInterface.t()) :: %{EVM.address() => EVM.val()}
  def dump_storage(account_interface) do
    account_interface.state
    |> Trie.Inspector.all_values()
    |> Enum.into(%{})
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
  @spec message_call(
          AccountInterface.t(),
          EVM.address(),
          EVM.address(),
          EVM.address(),
          EVM.address(),
          EVM.Gas.t(),
          EVM.Gas.gas_price(),
          EVM.Wei.t(),
          EVM.Wei.t(),
          binary(),
          integer(),
          Block.Header.t()
        ) :: {AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  def message_call(
        account_interface,
        evm_sender,
        evm_originator,
        evm_recipient,
        evm_contract,
        available_gas,
        gas_price,
        value,
        apparent_value,
        data,
        stack_depth,
        block_header
      ) do
    sender = Account.Address.from(evm_sender)
    originator = Account.Address.from(evm_originator)
    recipient = Account.Address.from(evm_recipient)
    contract = Account.Address.from(evm_contract)

    params = %Contract.MessageCall{
      account_interface: account_interface,
      sender: sender,
      originator: originator,
      recipient: recipient,
      contract: contract,
      available_gas: available_gas,
      gas_price: gas_price,
      value: value,
      apparent_value: apparent_value,
      data: data,
      stack_depth: stack_depth,
      block_header: block_header
    }

    {_status, result} = Contract.message_call(params)

    result
  end

  @doc """
  Creates a new contract on the blockchain.

  ## Examples

      iex> {:ok, {account_interface, _gas, _sub_state}} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 11, nonce: 5})
      ...> |> Blockchain.Interface.AccountInterface.new()
      ...> |> EVM.Interface.AccountInterface.create_contract(<<0x10::160>>, <<0x10::160>>, 1000, 1, 5, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]), 5, %Block.Header{nonce: 1}, nil,  EVM.Configuration.Frontier.new())
      iex> account_interface.state.root_hash
      <<226, 121, 240, 77, 157, 98, 127, 111, 137, 201, 186, 41, 100, 239,
              227, 209, 92, 247, 21, 58, 119, 4, 191, 255, 84, 144, 86, 99, 178,
              157, 145, 31>>
  """
  @spec create_contract(
          AccountInterface.t(),
          EVM.address(),
          EVM.address(),
          EVM.Gas.t(),
          EVM.Gas.gas_price(),
          EVM.Wei.t(),
          EVM.MachineCode.t(),
          integer(),
          Block.Header.t(),
          EVM.address() | nil,
          EVM.Configuration.t()
        ) :: {:ok | :error, {AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t()}}
  def create_contract(
        account_interface,
        evm_sender,
        evm_originator,
        available_gas,
        gas_price,
        endowment,
        init_code,
        stack_depth,
        block_header,
        new_account_address,
        config
      ) do
    sender = Account.Address.from(evm_sender)
    originator = Account.Address.from(evm_originator)

    params = %Contract.CreateContract{
      account_interface: account_interface,
      sender: sender,
      originator: originator,
      available_gas: available_gas,
      gas_price: gas_price,
      endowment: endowment,
      init_code: init_code,
      stack_depth: stack_depth,
      block_header: block_header,
      new_account_address: new_account_address,
      config: config
    }

    Contract.create(params)
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
  @spec new_contract_address(AccountInterface.t(), EVM.address(), integer()) :: EVM.address()
  def new_contract_address(_account_interface, evm_address, nonce) do
    evm_address
    |> Account.Address.from()
    |> Account.Address.new(nonce)
  end

  @spec clear_balance(AccountInterface.t(), EVM.address()) :: AccountInterface.t()
  def clear_balance(account_interface, evm_address) do
    address = Account.Address.from(evm_address)
    state = Account.clear_balance(account_interface.state, address)

    Map.put(account_interface, :state, state)
  end
end
