defmodule Blockchain.Account.Repo.Cache do
  alias ExthCrypto.Hash.Keccak
  alias Blockchain.Account
  alias Blockchain.Account.Address
  alias Blockchain.Account.Storage
  alias MerklePatriciaTree.TrieStorage

  defstruct storage_cache: %{}, accounts_cache: %{}

  @type current_value :: integer() | :deleted
  @type initial_value :: integer() | nil | :account_not_found | :key_not_found

  @type key_cache() :: %{
          integer() => %{current_value: current_value(), initial_value: initial_value()}
        }
  @type maybe_code :: {:clean | :dirty, EVM.MachineCode.t()} | nil
  @type maybe_account :: Account.t() | nil
  @type account_code_tuple :: {:dirty | :clean, maybe_account, maybe_code}
  @type storage_cache :: %{Address.t() => key_cache()}
  @type cached_account_info :: account_code_tuple | nil
  @type accounts_cache :: %{Address.t() => cached_account_info}
  @type t :: %__MODULE__{
          storage_cache: storage_cache(),
          accounts_cache: accounts_cache()
        }
  @type changes :: [%{Address.t() => {:update | :clean, Account.t()} | :delete}]

  @spec current_value(t(), Address.t(), integer()) :: integer() | :deleted | nil
  def current_value(cache_struct, address, key) do
    key_value(cache_struct.storage_cache, address, key, :current_value)
  end

  @spec initial_value(t(), Address.t(), integer()) :: initial_value()
  def initial_value(cache_struct, address, key) do
    key_value(cache_struct.storage_cache, address, key, :initial_value)
  end

  @spec update_current_value(t(), Address.t(), integer(), integer()) :: t()
  def update_current_value(cache_struct, address, key, value) do
    cache_update = %{key => %{current_value: value}}

    updated_cache = update_key_cache(cache_struct.storage_cache, address, cache_update)

    %{cache_struct | storage_cache: updated_cache}
  end

  @spec add_initial_value(t(), Address.t(), integer(), initial_value()) :: t()
  def add_initial_value(cache_struct, address, key, value) do
    cache_update = %{key => %{initial_value: value}}

    updated_cache = update_key_cache(cache_struct.storage_cache, address, cache_update)

    %{cache_struct | storage_cache: updated_cache}
  end

  @spec remove_current_value(t(), Address.t(), integer()) :: t()
  def remove_current_value(cache_struct, address, key) do
    cache_update = %{key => %{current_value: :deleted}}

    updated_cache = update_key_cache(cache_struct.storage_cache, address, cache_update)

    %{cache_struct | storage_cache: updated_cache}
  end

  @spec reset_account_storage_cache(t(), Address.t()) :: t()
  def reset_account_storage_cache(cache_struct, address) do
    updated_storage_cache = Map.delete(cache_struct.storage_cache, address)

    %{cache_struct | storage_cache: updated_storage_cache}
  end

  @spec account(t(), Address.t()) :: cached_account_info()
  def account(cache_struct, address) do
    Map.get(cache_struct.accounts_cache, address)
  end

  @spec update_account(t(), Address.t(), cached_account_info()) :: t()
  def update_account(cache_struct, address, account) do
    updated_accounts_cache = Map.put(cache_struct.accounts_cache, address, account)

    %{cache_struct | accounts_cache: updated_accounts_cache}
  end

  @spec commit(t(), TrieStorage.t()) :: TrieStorage.t()
  def commit(cache_struct, state) do
    cache_struct
    |> normalize_changes_and_save_code(state)
    |> commit_storage(cache_struct)
    |> commit_accounts()
  end

  @spec commit_storage(t(), TrieStorage.t()) :: {TrieStorage.t(), changes()}
  def commit_storage({state, changes}, cache_struct) do
    cache_struct
    |> storage_to_list()
    |> Enum.reduce({state, changes}, fn account_storage_cache, {state_acc, changes} ->
      commit_account_storage_cache(account_storage_cache, state_acc, changes)
    end)
  end

  @spec normalize_changes_and_save_code(t(), TrieStorage.t()) :: {TrieStorage.t(), changes()}
  def normalize_changes_and_save_code(cache_struct, state) do
    cache_struct
    |> accounts_to_list()
    |> Enum.reduce({state, %{}}, &normalize_changes/2)
  end

  @spec storage_to_list(t()) :: list()
  def storage_to_list(cache_struct) do
    Map.to_list(cache_struct.storage_cache)
  end

  @spec accounts_to_list(t()) :: list()
  def accounts_to_list(cache_struct) do
    Map.to_list(cache_struct.accounts_cache)
  end

  defp key_value(cache, address, key, value_name) do
    with account_cache = %{} <- Map.get(cache, address),
         key_cache = %{} <- Map.get(account_cache, key) do
      Map.get(key_cache, value_name)
    end
  end

  defp update_key_cache(cache, address, key_cache_update) do
    cache_update = %{address => key_cache_update}

    Map.merge(cache, cache_update, fn _k, account_cache, new_account_cache ->
      Map.merge(account_cache, new_account_cache, fn _k, old_key_cache, new_key_cache ->
        Map.merge(old_key_cache, new_key_cache, fn _k, _old_value, new_value -> new_value end)
      end)
    end)
  end

  defp normalize_changes({address, {:dirty, nil, _code}}, {state, result}) do
    change = :delete
    updated_result = Map.put(result, address, change)

    {state, updated_result}
  end

  defp normalize_changes({address, {:dirty, account, {:dirty, machine_code}}}, {state, result}) do
    code_hash = Keccak.kec(machine_code)
    new_state = TrieStorage.put_raw_key!(state, code_hash, machine_code)
    updated_account = %{account | code_hash: code_hash}

    change = {:update, updated_account}
    updated_result = Map.put(result, address, change)

    {new_state, updated_result}
  end

  defp normalize_changes({address, {:dirty, account, _code}}, {state, result}) do
    change = {:update, account}
    updated_result = Map.put(result, address, change)

    {state, updated_result}
  end

  defp normalize_changes({address, {:clean, account, _code}}, {state, result}) do
    change = {:clean, account}
    updated_result = Map.put(result, address, change)

    {state, updated_result}
  end

  defp commit_account_storage_cache({address, account_cache}, state_trie, changes) do
    account_with_status =
      case Map.get(changes, address) do
        {status, account} -> {status, account}
        _ -> {:clean, Account.get_account(state_trie, address)}
      end

    {updated_account, updated_state} =
      account_cache
      |> Map.to_list()
      |> Enum.reduce({account_with_status, state_trie}, &commit_key_cache(address, &1, &2))

    updated_changes = Map.put(changes, address, updated_account)

    {updated_state, updated_changes}
  end

  defp commit_key_cache(
         _address,
         {key, _key_cache = %{current_value: :deleted}},
         {{_status, account}, state}
       ) do
    {updated_storage_state, updated_state} = Storage.remove(state, account.storage_root, key)

    root_hash = TrieStorage.root_hash(updated_storage_state)
    updated_account = %{account | storage_root: root_hash}

    {{:update, updated_account}, updated_state}
  end

  defp commit_key_cache(
         _address,
         {key, %{current_value: current_value}},
         {{_status, account}, state}
       ) do
    {updated_storage_state, updated_state} =
      Storage.put(state, account.storage_root, key, current_value)

    root_hash = TrieStorage.root_hash(updated_storage_state)
    updated_account = %{account | storage_root: root_hash}

    {{:update, updated_account}, updated_state}
  end

  defp commit_key_cache(_address, {_key, _key_cache}, {account_with_status, state}) do
    {account_with_status, state}
  end

  defp commit_accounts({state, changes}) do
    changes
    |> Map.to_list()
    |> Enum.reduce(state, fn {address, change}, state_acc ->
      case change do
        :delete -> Account.del_account(state_acc, address)
        {:update, account} -> Account.put_account(state_acc, address, account)
        _ -> state_acc
      end
    end)
  end
end
