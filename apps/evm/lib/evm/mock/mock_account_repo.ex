defmodule EVM.Mock.MockAccountRepo do
  @moduledoc """
  Simple implementation of an EVM.AccountRepo.
  """

  @behaviour EVM.AccountRepo

  defstruct account_map: %{},
            contract_result: %{
              gas: nil,
              sub_state: nil,
              output: nil
            }

  def new(account_map \\ %{}, contract_result \\ %{}) do
    %__MODULE__{
      account_map: account_map,
      contract_result: contract_result
    }
  end

  def add_account(interface, address, account) do
    account_map = Map.put(interface.account_map, address, account)

    %{interface | account_map: account_map}
  end

  @impl true
  def account_exists?(mock_account_repo, address) do
    account = get_account(mock_account_repo, :binary.decode_unsigned(address))

    !is_nil(account)
  end

  @impl true
  def empty_account?(mock_account_repo, address) do
    account_exists?(mock_account_repo, address)
  end

  @impl true
  def get_account_balance(mock_account_repo, address) do
    account = get_account(mock_account_repo, address)

    if account do
      account.balance
    else
      nil
    end
  end

  @impl true
  def add_wei(mock_account_repo, address, value) do
    account = get_account(mock_account_repo, address) || new_account()

    put_account(mock_account_repo, address, %{account | balance: account.balance + value})
  end

  @impl true
  def transfer(mock_account_repo, from, to, value) do
    mock_account_repo
    |> add_wei(from, -value)
    |> add_wei(to, value)
  end

  @impl true
  def get_account_code(mock_account_repo, address) do
    account = get_account(mock_account_repo, address)

    if account do
      account.code
    else
      <<>>
    end
  end

  @impl true
  def get_account_code_hash(mock_account_repo, address) do
    account = get_account(mock_account_repo, address)

    unless is_nil(account), do: account.code_hash
  end

  defp get_account(mock_account_repo, address) do
    Map.get(mock_account_repo.account_map, address)
  end

  @impl true
  def increment_account_nonce(mock_account_repo, address) do
    account = Map.get(mock_account_repo.account_map, address)
    updated_account = %{account | nonce: account.nonce + 1}
    account_map = Map.put(mock_account_repo.account_map, address, updated_account)

    %{mock_account_repo | account_map: account_map}
  end

  @impl true
  def get_storage(mock_account_repo, address, key) do
    case mock_account_repo.account_map[address] do
      nil ->
        :account_not_found

      account ->
        case account[:storage][key] do
          nil -> :key_not_found
          value -> {:ok, value}
        end
    end
  end

  @impl true
  def get_initial_storage(mock_account_repo, address, key) do
    get_storage(mock_account_repo, address, key)
  end

  @impl true
  def put_storage(mock_account_repo, address, key, value) do
    account = get_account(mock_account_repo, address)

    account =
      if account do
        update_storage(account, key, value)
      else
        new_account(%{storage: %{key => value}})
      end

    put_account(mock_account_repo, address, account)
  end

  @impl true
  def remove_storage(mock_account_repo, address, key) do
    account = get_account(mock_account_repo, address)

    if account do
      account = update_storage(account, key, 0)
      put_account(mock_account_repo, address, account)
    else
      mock_account_repo
    end
  end

  defp update_storage(account, key, value) do
    if value == 0 do
      {_key, value} = pop_in(account, [:storage, key])

      value
    else
      put_in(account, [:storage, key], value)
    end
  end

  defp put_account(mock_account_repo, address, account) do
    account_map = Map.put(mock_account_repo.account_map, address, account)
    %{mock_account_repo | account_map: account_map}
  end

  defp new_account(opts \\ %{}) do
    account = %{
      storage: %{},
      nonce: 0,
      code: <<>>,
      balance: 0
    }

    Map.merge(account, opts)
  end

  @impl true
  def get_account_nonce(mock_account_repo, address) do
    get_in(mock_account_repo.account_map, [address, :nonce])
  end

  @impl true
  def dump_storage(mock_account_repo) do
    for {address, account} <- mock_account_repo.account_map, into: %{} do
      storage =
        account[:storage]
        |> Enum.reject(fn {_key, value} -> value == 0 end)
        |> Enum.into(%{})

      {address, storage}
    end
  end

  @impl true
  def message_call(
        mock_account_repo,
        _sender,
        _originator,
        _recipient,
        _contract,
        _available_gas,
        _gas_price,
        _value,
        _apparent_value,
        _data,
        _stack_depth,
        _block_header
      ) do
    {
      mock_account_repo,
      mock_account_repo.contract_result[:gas],
      mock_account_repo.contract_result[:sub_state],
      mock_account_repo.contract_result[:output]
    }
  end

  @impl true
  def create_contract(
        mock_account_repo,
        _sender,
        _originator,
        _available_gas,
        _gas_price,
        _endowment,
        _init_code,
        _stack_depth,
        _block_header,
        _new_account_address,
        _config
      ) do
    {:ok,
     {
       mock_account_repo,
       mock_account_repo.contract_result[:gas],
       mock_account_repo.contract_result[:sub_state] || EVM.SubState.empty()
     }}
  end

  @impl true
  def new_contract_address(_mock_account_repo, address, _nonce) do
    address
  end

  @impl true
  def clear_balance(mock_account_repo, address) do
    account = get_account(mock_account_repo, address)

    put_account(mock_account_repo, address, %{account | balance: 0})
  end
end
