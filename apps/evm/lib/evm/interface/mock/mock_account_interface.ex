defmodule EVM.Interface.Mock.MockAccountInterface do
  @moduledoc """
  Simple implementation of an AccountInterface.
  """

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
end

defimpl EVM.Interface.AccountInterface, for: EVM.Interface.Mock.MockAccountInterface do
  alias Block.Header

  @spec account_exists?(EVM.Interface.AccountInterface.t(), EVM.address()) :: boolean()
  def account_exists?(mock_account_interface, address) do
    account = get_account(mock_account_interface, :binary.decode_unsigned(address))

    !is_nil(account)
  end

  @spec empty_account?(EVM.Interface.AccountInterface.t(), EVM.address()) :: boolean()
  def empty_account?(mock_account_interface, address) do
    account_exists?(mock_account_interface, address)
  end

  @spec get_account_balance(EVM.Interface.AccountInterface.t(), EVM.address()) ::
          nil | EVM.Wei.t()
  def get_account_balance(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.balance
    else
      nil
    end
  end

  @spec add_wei(EVM.Interface.AccountInterface.t(), EVM.address(), integer()) ::
          EVM.Interface.AccountInterface.t()
  def add_wei(mock_account_interface, address, value) do
    account = get_account(mock_account_interface, address) || new_account()

    put_account(mock_account_interface, address, %{account | balance: account.balance + value})
  end

  @spec transfer(EVM.Interface.AccountInterface.t(), EVM.address(), EVM.address(), integer()) ::
          EVM.Interface.AccountInterface.t()
  def transfer(mock_account_interface, from, to, value) do
    mock_account_interface
    |> add_wei(from, -value)
    |> add_wei(to, value)
  end

  @spec get_account_code(EVM.Interface.AccountInterface.t(), EVM.address()) :: nil | binary()
  def get_account_code(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.code
    else
      <<>>
    end
  end

  @spec get_account_code_hash(EVM.Interface.AccountInterface.t(), EVM.address()) :: binary() | nil
  def get_account_code_hash(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    unless is_nil(account), do: account.code_hash
  end

  defp get_account(mock_account_interface, address) do
    Map.get(mock_account_interface.account_map, address)
  end

  @spec increment_account_nonce(EVM.Interface.AccountInterface.t(), EVM.address()) ::
          {EVM.Interface.AccountInterface.t(), integer()}
  def increment_account_nonce(mock_account_interface, address) do
    {
      mock_account_interface,
      Map.get(mock_account_interface.account_map, address).nonce + 1
    }
  end

  # TODO: Integrate new interface
  @spec get_storage(EVM.Interface.AccountInterface.t(), EVM.address(), integer()) ::
          {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(mock_account_interface, address, key) do
    case mock_account_interface.account_map[address] do
      nil ->
        :account_not_found

      account ->
        case account[:storage][key] do
          nil -> :key_not_found
          value -> {:ok, value}
        end
    end
  end

  @spec put_storage(EVM.Interface.AccountInterface.t(), EVM.address(), integer(), integer()) ::
          EVM.Interface.AccountInterface.t()
  def put_storage(mock_account_interface, address, key, value) do
    account = get_account(mock_account_interface, address)

    account =
      if account do
        update_storage(account, key, value)
      else
        new_account(%{storage: %{key => value}})
      end

    put_account(mock_account_interface, address, account)
  end

  @spec remove_storage(EVM.Interface.AccountInterface.t(), EVM.address(), integer()) ::
          EVM.Interface.AccountInterface.t()
  def remove_storage(mock_account_interface, address, key) do
    account = get_account(mock_account_interface, address)

    if account do
      account = update_storage(account, key, 0)
      put_account(mock_account_interface, address, account)
    else
      mock_account_interface
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

  defp put_account(mock_account_interface, address, account) do
    account_map = Map.put(mock_account_interface.account_map, address, account)
    %{mock_account_interface | account_map: account_map}
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

  @spec get_account_nonce(EVM.Interface.AccountInterface.t(), EVM.address()) :: integer()
  def get_account_nonce(mock_account_interface, address) do
    get_in(mock_account_interface.account_map, [address, :nonce])
  end

  @spec dump_storage(EVM.Interface.AccountInterface.t()) :: %{EVM.address() => EVM.val()}
  def dump_storage(mock_account_interface) do
    for {address, account} <- mock_account_interface.account_map, into: %{} do
      storage =
        account[:storage]
        |> Enum.reject(fn {_key, value} -> value == 0 end)
        |> Enum.into(%{})

      {address, storage}
    end
  end

  @spec message_call(
          EVM.Interface.AccountInterface.t(),
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
          Header.t()
        ) :: {EVM.Interface.AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  def message_call(
        mock_account_interface,
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
      mock_account_interface,
      mock_account_interface.contract_result[:gas],
      mock_account_interface.contract_result[:sub_state],
      mock_account_interface.contract_result[:output]
    }
  end

  @spec create_contract(
          EVM.Interface.AccountInterface.t(),
          EVM.address(),
          EVM.address(),
          EVM.Gas.t(),
          EVM.Gas.gas_price(),
          EVM.Wei.t(),
          EVM.MachineCode.t(),
          integer(),
          Header.t(),
          EVM.Configuration.t()
        ) :: {:ok | :error, {EVM.Gas.t(), EVM.Interface.AccountInterface.t(), EVM.SubState.t()}}
  def create_contract(
        mock_account_interface,
        _sender,
        _originator,
        _available_gas,
        _gas_price,
        _endowment,
        _init_code,
        _stack_depth,
        _block_header,
        _config
      ) do
    {:ok,
     {
       mock_account_interface,
       mock_account_interface.contract_result[:gas],
       mock_account_interface.contract_result[:sub_state] || EVM.SubState.empty()
     }}
  end

  @spec new_contract_address(EVM.Interface.AccountInterface.t(), EVM.address(), integer()) ::
          EVM.address()
  def new_contract_address(_mock_account_interface, address, _nonce) do
    address
  end

  @spec clear_balance(EVM.Interface.AccountInterface.t(), EVM.address()) :: EVM.address()
  def clear_balance(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    put_account(mock_account_interface, address, %{account | balance: 0})
  end
end
