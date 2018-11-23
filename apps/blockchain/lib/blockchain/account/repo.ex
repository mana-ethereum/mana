defmodule Blockchain.Account.Repo do
  @moduledoc """
  Module to interact with contracts and accounts.
  """
  alias Blockchain.{Account, Contract}
  alias Blockchain.Account.Address
  alias Blockchain.Account.Repo.Cache
  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.Trie

  @behaviour EVM.AccountRepo

  @type t :: %__MODULE__{
          state: Trie.t(),
          cache: Cache.t()
        }

  defstruct [
    :state,
    :cache
  ]

  @doc """
  Returns a new account repo.

  ## Examples

      iex> state = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(:account_repo_new))
      iex> Blockchain.Account.Repo.new(state)
      %Blockchain.Account.Repo{
        state: %MerklePatriciaTree.Trie{
          db: { MerklePatriciaTree.DB.ETS, :account_repo_new },
          root_hash: <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
        },
        cache: %Blockchain.Account.Repo.Cache{storage_cache: %{}, accounts_cache: %{}}
      }
  """
  @spec new(Trie.t(), Cache.t()) :: t
  def new(state, cache \\ %Cache{}) do
    %__MODULE__{
      state: state,
      cache: cache
    }
  end

  @spec commit(t()) :: t()
  def commit(account_repo) do
    account_repo.cache
    |> Cache.commit(account_repo.state)
    |> new()
  end

  @spec put_account(t(), Address.t(), Account.t(), atom()) :: t()
  def put_account(account_repo, address, account, state \\ :dirty)
      when state in [:dirty, :clean] do
    updated_cache = Cache.update_account(account_repo.cache, address, {state, account, nil})

    %{account_repo | cache: updated_cache}
  end

  @spec reset_cache(t()) :: t()
  def reset_cache(account_repo) do
    new(account_repo.state)
  end

  @spec set_empty_storage_root(t(), Address.t()) :: t()
  def set_empty_storage_root(account_repo, address) do
    {updated_account_repo, account, code} = account_with_code(account_repo, address)

    updated_account = %{account | storage_root: MerklePatriciaTree.Trie.empty_trie_root_hash()}

    updated_cache =
      Cache.update_account(updated_account_repo.cache, address, {:dirty, updated_account, code})

    %{account_repo | cache: updated_cache}
  end

  @impl true
  def increment_account_nonce(account_repo, evm_address) do
    address = Account.Address.from(evm_address)

    {_repo, account, code} = account_with_code(account_repo, address)
    updated_account = %{account | nonce: account.nonce + 1}

    updated_cache =
      Cache.update_account(account_repo.cache, address, {:dirty, updated_account, code})

    %{account_repo | cache: updated_cache}
  end

  @spec transfer_wei!(t(), Address.t(), Address.t(), EVM.Wei.t()) :: t()
  def transfer_wei!(account_repo, from, to, wei) do
    {updated_repo, from_account, from_account_code} = account_with_code(account_repo, from)

    cond do
      wei < 0 ->
        raise("wei transfer cannot be negative")

      from_account == nil ->
        raise("sender account does not exist")

      from_account.balance < wei ->
        raise("sender account insufficient wei")

      from == to ->
        updated_repo

      true ->
        {_repo, to_account, to_account_code} = account_with_code(account_repo, to)
        to_account = to_account || Account.not_persistent_account()

        new_from_account = %{from_account | balance: from_account.balance - wei}
        new_to_account = %{to_account | balance: to_account.balance + wei}

        updated_cache =
          account_repo.cache
          |> Cache.update_account(from, {:dirty, new_from_account, from_account_code})
          |> Cache.update_account(to, {:dirty, new_to_account, to_account_code})

        %{account_repo | cache: updated_cache}
    end
  end

  @spec add_wei(t, EVM.address(), integer()) :: t
  def add_wei(account_repo, evm_address, value) do
    address = Account.Address.from(evm_address)

    {_repo, account, code} = account_with_code(account_repo, address)

    account = account || Account.not_persistent_account()

    updated_account = %{account | balance: account.balance + value}

    if updated_account.balance < 0, do: raise("wei reduced to less than zero")

    updated_cache =
      Cache.update_account(account_repo.cache, address, {:dirty, updated_account, code})

    %{account_repo | cache: updated_cache}
  end

  @spec del_account(t(), Address.t()) :: t()
  def del_account(account_repo, address) do
    updated_cache =
      account_repo.cache
      |> Cache.update_account(address, {:dirty, nil, nil})
      |> Cache.reset_account_storage_cache(address)

    %{account_repo | cache: updated_cache}
  end

  @spec dec_wei(t(), Address.t(), EVM.Wei.t()) :: t()
  def dec_wei(account_repo, address, value) do
    add_wei(account_repo, address, -1 * value)
  end

  @spec put_code(t(), Address.t(), EVM.MachineCode.t()) :: t()
  def put_code(account_repo, address, machine_code) do
    kec = Keccak.kec(machine_code)

    {_repo, account, _} = account_with_code(account_repo, address)

    updated_account = %{(account || Account.not_persistent_account()) | code_hash: kec}

    updated_cache =
      Cache.update_account(
        account_repo.cache,
        address,
        {:dirty, updated_account, {:dirty, machine_code}}
      )

    %{account_repo | cache: updated_cache}
  end

  @spec machine_code(t(), Address.t()) :: {t(), {:ok, binary()}} | {t(), :not_found}
  def machine_code(account_repo, address) do
    {updated_repo, account, code} = account_with_code(account_repo, address)

    cond do
      is_nil(account) ->
        {updated_repo, {:ok, <<>>}}

      is_nil(code) ->
        cache_and_get_code(updated_repo, address, account)

      true ->
        {_status, code} = code

        {account_repo, {:ok, code}}
    end
  end

  @impl true
  def clear_balance(account_repo, evm_address) do
    address = Account.Address.from(evm_address)
    {_repo, account, code} = account_with_code(account_repo, address)

    updated_account = %{account | balance: 0}

    updated_cache =
      Cache.update_account(account_repo.cache, address, {:dirty, updated_account, code})

    %{account_repo | cache: updated_cache}
  end

  @spec reset_account(t(), Address.t()) :: t()
  def reset_account(account_repo, address, account \\ %Account{}) do
    updated_cache = Cache.update_account(account_repo.cache, address, {:dirty, account, nil})

    %{account_repo | cache: updated_cache}
  end

  @spec account_with_code(t(), Address.t()) :: {t(), Cache.maybe_account(), Cache.maybe_code()}
  def account_with_code(account_repo, address) do
    cached_account = account_from_cache(account_repo.cache, address)

    {found_account, updated_repo} =
      if cached_account do
        {cached_account, account_repo}
      else
        storage_account = account_from_storage(account_repo.state, address)

        updated_repo = put_account(account_repo, address, storage_account, :clean)

        {storage_account, updated_repo}
      end

    case found_account do
      {_status, account, code} -> {updated_repo, account, code}
      account -> {updated_repo, account, nil}
    end
  end

  @spec account(t(), Address.t()) :: {t(), Account.t() | nil}
  def account(account_repo, address) do
    {repo, account, _code} = account_with_code(account_repo, address)

    {repo, account}
  end

  @spec account_from_storage(Trie.t(), Address.t()) :: Account.t() | nil
  defp account_from_storage(state, address) do
    Account.get_account(state, address)
  end

  @spec account_from_cache(Cache.t(), Address.t()) :: Cache.cached_account_info()
  defp account_from_cache(cache, address) do
    Cache.account(cache, address)
  end

  @doc """
  Given an account interface and an address, returns the balance at that address.

  Note, if the account is nil (doesn't exist), we return nil.

  ## Examples

      iex> {_repo, balance} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.account_balance(<<1::160>>)
      iex> balance
      5

      iex> {_repo, balance} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.account_balance(<<2::160>>)
      iex> balance
      nil
  """
  @impl true
  def account_balance(account_repo, evm_address) do
    address = Account.Address.from(evm_address)

    {updated_repo, account} = account(account_repo, address)

    balance =
      case account do
        nil -> nil
        account -> account.balance
      end

    {updated_repo, balance}
  end

  @impl true
  def transfer(account_repo, evm_from, evm_to, value) do
    from = Account.Address.from(evm_from)
    to = Account.Address.from(evm_to)

    transfer_wei!(account_repo, from, to, value)
  end

  @doc """
  Given an account interface and an address, returns the code stored at given address.

  Note, if the account is nil (doesn't exist), we return nil.

  ## Examples

      iex> {_repo, code} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_code(<<1::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.account_code(<<1::160>>)
      iex> code
      <<1, 2, 3>>

      iex> {_repo, code} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_code(<<1::160>>, <<1, 2, 3>>)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.account_code(<<2::160>>)
      iex> code
      <<>>
  """
  @impl true
  def account_code(account_repo, evm_address) do
    address = Account.Address.from(evm_address)

    {updated_repo, {:ok, code}} = machine_code(account_repo, address)

    {updated_repo, code}
  end

  @impl true
  def account_code_hash(account_repo, address) do
    {repo, account} = account(account_repo, address)

    code_hash = unless is_nil(account), do: account.code_hash

    {repo, code_hash}
  end

  @doc """
  Given an account interface, an account address and a key, returns the value of
  that given in the account's personal storage.

  ## Examples

      iex> {_repo, result} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.storage(<<1::160>>, 5)
      iex> result
      {:ok, 6}

      iex> {_repo, result} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.storage(<<1::160>>, 6)
      iex> result
      :key_not_found

      iex> {_repo, result} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.storage(<<2::160>>, 5)
      iex> result
      :account_not_found
  """
  @impl true
  def storage(account_repo, evm_address, key) do
    address = Account.Address.from(evm_address)

    cached_value =
      Cache.current_value(account_repo.cache, address, key) ||
        Cache.initial_value(account_repo.cache, address, key)

    case cached_value do
      nil ->
        cache_and_get_initial_storage_value(account_repo, address, key)

      :deleted ->
        {account_repo, :key_not_found}

      :key_not_found ->
        {account_repo, :key_not_found}

      :account_not_found ->
        {account_repo, :account_not_found}

      _ ->
        {account_repo, {:ok, cached_value}}
    end
  end

  @impl true
  def initial_storage(account_repo, evm_address, key) do
    address = Account.Address.from(evm_address)
    cached_value = Cache.initial_value(account_repo.cache, address, key)

    case cached_value do
      nil ->
        cache_and_get_initial_storage_value(account_repo, address, key)

      :account_not_found ->
        {account_repo, :account_not_found}

      :key_not_found ->
        {account_repo, :key_not_found}

      cached_value ->
        {account_repo, {:ok, cached_value}}
    end
  end

  @impl true
  def account_exists?(account_repo, evm_address) do
    address = Account.Address.from(evm_address)
    {repo, account} = account(account_repo, address)

    {repo, !is_nil(account)}
  end

  @impl true
  def empty_account?(account_repo, evm_address) do
    address = Account.Address.from(evm_address)
    {repo, account} = account(account_repo, address)

    empty_flag = !is_nil(account) && Account.empty?(account)

    {repo, empty_flag}
  end

  @doc """
  Given an account interface, an account address, a key and a value, puts the
  value at that key location, overwriting any previous value.

  ## Examples

      iex> {_repo, result} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.put_storage(<<1::160>>, 5, 6)
      ...> |> Blockchain.Account.Repo.storage(<<1::160>>, 5)
      iex> result
      :account_not_found
  """
  @impl true
  def put_storage(account_repo, evm_address, key, value) do
    address = Account.Address.from(evm_address)
    {updated_repo, account} = account(account_repo, address)

    if account do
      updated_cache = Cache.update_current_value(updated_repo.cache, address, key, value)

      %{updated_repo | cache: updated_cache}
    else
      updated_repo
    end
  end

  @impl true
  def remove_storage(account_repo, evm_address, key) do
    address = Account.Address.from(evm_address)
    {updated_repo, account} = account(account_repo, address)

    if account do
      updated_cache = Cache.remove_current_value(updated_repo.cache, address, key)

      %{account_repo | cache: updated_cache}
    else
      updated_repo
    end
  end

  @doc """
  Given an account interface and an address, returns the nonce at that address.

  ## Examples

      iex> account_repo =
      ...> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.add_wei(<<1::160>>, 5)
      ...> |> Blockchain.Account.Repo.new()
      iex> {_repo, nonce} = Blockchain.Account.Repo.account_nonce(account_repo, <<1::160>>)
      iex> nonce
      0
      iex> account_repo =
      ...> Blockchain.Account.Repo.increment_account_nonce(account_repo, <<1::160>>)
      iex> {_repo, nonce} = Blockchain.Account.Repo.account_nonce(account_repo, <<1::160>>)
      iex> nonce
      1
  """
  @impl true
  def account_nonce(account_repo, evm_address) do
    address = Account.Address.from(evm_address)
    {updated_repo, account} = account(account_repo, address)

    nonce = if account, do: account.nonce, else: nil

    {updated_repo, nonce}
  end

  @doc """
  Given an account interface, dumps all key-value pairs.
  This should only be used for testing and debugging.

  ## Examples

      iex> MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> MerklePatriciaTree.Trie.update_key(<<5>>, <<6>>)
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.dump_storage()
      %{<<5>> => <<6>>}
  """
  @impl true
  def dump_storage(account_repo) do
    account_repo.state
    |> Trie.Inspector.all_values()
    |> Enum.into(%{})
  end

  @doc """
  Creates a new contract on the blockchain.

  ## Examples

      iex> {:ok, {account_repo, _gas, _sub_state, _output}} = MerklePatriciaTree.Test.random_ets_db()
      ...> |> MerklePatriciaTree.Trie.new()
      ...> |> Blockchain.Account.put_account(<<0x10::160>>, %Blockchain.Account{balance: 11, nonce: 5})
      ...> |> Blockchain.Account.Repo.new()
      ...> |> Blockchain.Account.Repo.create_contract(<<0x10::160>>, <<0x10::160>>, 1000, 1, 5, EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 32, :push1, 0, :return]), 5, %Block.Header{nonce: 1}, nil,  EVM.Configuration.Frontier.new())
      ...> Blockchain.Account.Repo.commit(account_repo).state.root_hash
      <<226, 121, 240, 77, 157, 98, 127, 111, 137, 201, 186, 41, 100, 239,
              227, 209, 92, 247, 21, 58, 119, 4, 191, 255, 84, 144, 86, 99, 178,
              157, 145, 31>>
  """
  @impl true
  def create_contract(
        account_repo,
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
      account_repo: account_repo,
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

  @spec cache_and_get_initial_storage_value(t(), Address.t(), integer()) ::
          {t(), :key_not_found | :account_not_found | {:ok, integer()}}
  defp cache_and_get_initial_storage_value(account_repo, address, key) do
    {updated_repo, account} = account(account_repo, address)

    stored_value = Account.get_storage(updated_repo.state, account, key)

    found_value =
      case stored_value do
        :account_not_found ->
          if account, do: :key_not_found, else: :account_not_found

        stored_value ->
          stored_value
      end

    value_to_cache =
      case found_value do
        {:ok, value} -> value
        status -> status
      end

    updated_cache = Cache.add_initial_value(updated_repo.cache, address, key, value_to_cache)

    updated_account_repo = %{account_repo | cache: updated_cache}

    {updated_account_repo, found_value}
  end

  @spec cache_and_get_code(t(), Address.t(), Account.t()) :: {t(), {:ok, binary()} | :not_found}
  defp cache_and_get_code(account_repo, address, %Account{code_hash: nil}) do
    value_to_cache = ""
    {status, account, _} = account_from_cache(account_repo.cache, address)

    updated_cache =
      Cache.update_account(
        account_repo.cache,
        address,
        {status, account, {:clean, value_to_cache}}
      )

    repo_with_cached_code = %{account_repo | cache: updated_cache}

    {repo_with_cached_code, {:ok, value_to_cache}}
  end

  defp cache_and_get_code(account_repo, address, account) do
    found_code = Account.machine_code(account_repo.state, account)

    value_to_cache =
      case found_code do
        {:ok, found_code} -> found_code
        _ -> :not_found
      end

    {status, account, _} = account_from_cache(account_repo.cache, address)

    updated_cache =
      Cache.update_account(
        account_repo.cache,
        address,
        {status, account, {:clean, value_to_cache}}
      )

    repo_with_cached_code = %{account_repo | cache: updated_cache}

    {repo_with_cached_code, found_code}
  end
end
