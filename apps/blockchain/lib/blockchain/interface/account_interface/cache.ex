defmodule Blockchain.Interface.AccountInterface.Cache do
  alias Blockchain.Account
  alias Blockchain.Account.Address
  defstruct cache: %{}

  @type key_cache() :: %{
          integer() => %{current_value: integer() | :deleted, initial_value: integer() | nil}
        }
  @type account_cache :: %{Address.t() => key_cache()}
  @type t :: %__MODULE__{
          cache: account_cache()
        }

  @spec get_current_value(t(), Address.t(), integer()) :: integer() | nil
  def get_current_value(cache_struct, address, key) do
    get_key_value(cache_struct.cache, address, key, :current_value)
  end

  @spec get_initial_value(t(), Address.t(), integer()) :: integer() | nil
  def get_initial_value(cache_struct, address, key) do
    get_key_value(cache_struct.cache, address, key, :initial_value)
  end

  @spec update_current_value(t(), Address.t(), integer(), integer()) :: t()
  def update_current_value(cache_struct, address, key, value) do
    cache_update = %{key => %{current_value: value}}

    updated_cache = update_key_cache(cache_struct.cache, address, cache_update)

    %{cache_struct | cache: updated_cache}
  end

  @spec add_initial_value(t(), Address.t(), integer(), integer()) :: t()
  def add_initial_value(cache_struct, address, key, value) do
    cache_update = %{key => %{initial_value: value}}

    updated_cache = update_key_cache(cache_struct.cache, address, cache_update)

    %{cache_struct | cache: updated_cache}
  end

  @spec remove_current_value(t(), Address.t(), integer()) :: t()
  def remove_current_value(cache_struct, address, key) do
    cache_update = %{key => %{current_value: :deleted}}

    updated_cache = update_key_cache(cache_struct.cache, address, cache_update)

    %{cache_struct | cache: updated_cache}
  end

  @spec commit(t(), EVM.state()) :: EVM.state()
  def commit(cache_struct, state) do
    cache_struct
    |> to_list()
    |> Enum.reduce(state, &commit_account_cache/2)
  end

  @spec to_list(t()) :: list()
  def to_list(cache_struct) do
    Map.to_list(cache_struct.cache)
  end

  defp get_key_value(cache, address, key, value_name) do
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

  defp commit_account_cache({address, account_cache}, state) do
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
