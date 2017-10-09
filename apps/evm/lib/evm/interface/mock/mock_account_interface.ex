defmodule EVM.Interface.Mock.MockAccountInterface do
  @moduledoc """
  Simple implementation of an AccountInterface.
  """

  defstruct [
    account_map: %{},
    contract_result: %{
      gas: nil,
      sub_state: nil,
      output: nil
    }
  ]

  def new(account_map \\ %{}, contract_result \\ %{}) do
    %__MODULE__{
      account_map: account_map,
      contract_result: contract_result
    }
  end

end

defimpl EVM.Interface.AccountInterface, for: EVM.Interface.Mock.MockAccountInterface do

  @spec account_exists?(EVM.Interface.AccountInterface.t, EVM.address) :: boolean()
  def account_exists?(mock_account_interface, address) do
    !!get_account(mock_account_interface, address)
  end

  @spec get_account_balance(EVM.Interface.AccountInterface.t, EVM.address) :: nil | EVM.Wei.t
  def get_account_balance(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.balance
    else
      nil
    end
  end

  @spec get_account_code(EVM.Interface.AccountInterface.t, EVM.address) :: nil | binary()
  def get_account_code(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    if account do
      account.code
    else
      nil
    end
  end

  defp get_account(mock_account_interface, address) do
    Map.get(mock_account_interface.account_map, address)
  end

  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: { EVM.Interface.AccountInterface.t, integer() }
  def increment_account_nonce(mock_account_interface, address) do
    {
      mock_account_interface,
      Map.get(mock_account_interface.account_map, address).nonce + 1
    }
  end

  # TODO: Integrate new interface
  @spec get_storage(EVM.Interface.AccountInterface.t, EVM.address, integer()) :: {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(mock_account_interface, address, key) do
    case mock_account_interface.account_map[address] do
      nil -> :account_not_found
      account ->
        case account[:storage][key] do
          nil -> :key_not_found
          value -> {:ok, value}
        end
    end
  end

  @spec put_storage(EVM.Interface.AccountInterface.t, EVM.address, integer(), integer()) :: EVM.Interface.AccountInterface.t
  def put_storage(mock_account_interface, address, key, value) do
    account = get_account(mock_account_interface, address)

    account = if account do
      update_storage(account, key, value)
    else
      new_account(%{
        storage: %{ key => value }
      })
    end

    put_account(mock_account_interface, address, account)
  end

  defp update_storage(account, key, value) do
    put_in(account, [:storage, key], value)
  end

  defp put_account(mock_account_interface, address, account) do
    %{mock_account_interface |
      account_map: Map.put(mock_account_interface.account_map, address, account)
    }
  end

  defp new_account(opts) do
    Map.merge(%{
      storage: %{},
      nonce: 0,
      balance: 0,
    }, opts)
  end

  @spec suicide_account(EVM.Interface.AccountInterface.t, EVM.address) :: EVM.Interface.AccountInterface.t
  def suicide_account(mock_account_interface, address) do
    account_map =
      mock_account_interface.account_map
      |> Map.delete(address)

    %{ mock_account_interface | account_map: account_map }
  end

  @spec get_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: integer()
  def get_account_nonce(mock_account_interface, address) do
    get_in(mock_account_interface.account_map, [address, :nonce])
  end
  @spec increment_account_nonce(EVM.Interface.AccountInterface.t, EVM.address) :: {integer(), EVM.Interface.AccountInterface.t}
  def increment_account_nonce(mock_account_interface, address) do
    account = get_account(mock_account_interface, address)

    nonce = if account do
      account.nonce
    else
      0
    end

    {
      nonce,
      put_account(mock_account_interface, address, %{account| nonce: nonce}),
    }
  end

  @spec dump_storage(EVM.Interface.AccountInterface.t) :: %{ EVM.address => EVM.val }
  def dump_storage(mock_account_interface) do
    for {address, account} <- mock_account_interface.account_map, into: %{} do
      storage = account[:storage]
        |> Enum.reject(fn({_key, value}) -> value == 0 end)
        |> Enum.into(%{})
      {address, storage}
    end
  end

  @spec message_call(EVM.Interface.AccountInterface.t, EVM.address, EVM.address, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.Wei.t, binary(), integer(), Header.t) :: { EVM.Interface.AccountInterface.t, EVM.Gas.t, EVM.SubState.t, EVM.VM.output }
  def message_call(mock_account_interface, _sender, _originator, _recipient, _contract, _available_gas, _gas_price, _value, _apparent_value, _data, _stack_depth, _block_header) do
    {
      mock_account_interface,
      mock_account_interface.contract_result[:gas],
      mock_account_interface.contract_result[:sub_state],
      mock_account_interface.contract_result[:output]
    }
  end

  @spec create_contract(EVM.Interface.AccountInterface.t, EVM.address, EVM.address, EVM.Gas.t, EVM.Gas.gas_price, EVM.Wei.t, EVM.MachineCode.t, integer(), Header.t) :: { EVM.Gas.t, EVM.Interface.AccountInterface.t, EVM.SubState.t }
  def create_contract(mock_account_interface, _sender, _originator, _available_gas, _gas_price, _endowment, _init_code, _stack_depth, _block_header) do
    {
      mock_account_interface,
      mock_account_interface.contract_result[:gas],
      mock_account_interface.contract_result[:sub_state]
    }
  end

  @spec new_contract_address(EVM.Interface.AccountInterface.t, EVM.address, integer()) :: EVM.address
  def new_contract_address(_mock_account_interface, address, _nonce) do
    address
  end

end
