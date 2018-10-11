defmodule Blockchain.Account.Repo.Cache do
  alias Blockchain.Account
  alias Blockchain.Account.Address
  alias MerklePatriciaTree.Trie

  defstruct storage_cache: %{}, accounts_cache: %{}

  @type key_cache() :: %{
          integer() => %{current_value: integer() | :deleted, initial_value: integer() | nil}
        }
  @type maybe_code :: EVM.MachineCode.t() | nil
  @type maybe_account :: Account.t() | nil
  @type account_code_tuple :: {maybe_account, maybe_code}
  @type storage_cache :: %{Address.t() => key_cache()}
  @type cached_account_info :: Account.t() | account_code_tuple | nil
  @type accounts_cache :: %{Address.t() => cached_account_info}
  @type t :: %__MODULE__{
          storage_cache: storage_cache(),
          accounts_cache: accounts_cache()
        }

  @spec current_value(t(), Address.t(), integer()) :: integer() | :deleted | nil
  def current_value(cache_struct, address, key) do
    key_value(cache_struct.storage_cache, address, key, :current_value)
  end

  @spec initial_value(t(), Address.t(), integer()) :: integer() | nil
  def initial_value(cache_struct, address, key) do
    key_value(cache_struct.storage_cache, address, key, :initial_value)
  end

  @spec update_current_value(t(), Address.t(), integer(), integer()) :: t()
  def update_current_value(cache_struct, address, key, value) do
    cache_update = %{key => %{current_value: value}}

    updated_cache = update_key_cache(cache_struct.storage_cache, address, cache_update)

    %{cache_struct | storage_cache: updated_cache}
  end

  @spec add_initial_value(t(), Address.t(), integer(), integer()) :: t()
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

  @spec commit(t(), Trie.t()) :: Trie.t()
  def commit(cache_struct, state) do
    committed_accounts = commit_accounts(cache_struct, state)

    commit_storage(cache_struct, committed_accounts)
  end

  @spec commit_storage(t(), Trie.t()) :: Trie.t()
  def commit_storage(cache_struct, state) do
    cache_struct
    |> storage_to_list()
    |> Enum.reduce(state, &commit_account_storage_cache/2)
  end

  @spec commit_accounts(t(), Trie.t()) :: Trie.t()
  def commit_accounts(cache_struct, state) do
    cache_struct
    |> accounts_to_list()
    |> Enum.reduce(state, &commit_account_cache/2)
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

  defp commit_account_cache({address, {account, code}}, state) do
    if is_nil(account) do
      Account.del_account(state, address)
    else
      state_with_account = Account.put_account(state, address, account)

      if code, do: Account.put_code(state_with_account, address, code), else: state_with_account
    end
  end

  defp commit_account_storage_cache({address, account_cache}, state) do
    account_cache
    |> Map.to_list()
    |> Enum.reduce(state, &commit_key_cache(address, &1, &2))
  end

  defp commit_key_cache(address, {key, key_cache}, state) do
    case Map.get(key_cache, :current_value) do
      :deleted -> Account.remove_storage(state, address, key)
      value -> Account.put_storage(state, address, key, value)
    end
  end
end
