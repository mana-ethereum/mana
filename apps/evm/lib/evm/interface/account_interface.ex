defprotocol EVM.Interface.AccountInterface do
  alias Block.Header

  @moduledoc """
  Interface for interacting with accounts.
  """

  @type t :: module()

  @spec account_exists?(t, EVM.address()) :: boolean()
  def account_exists?(t, address)

  @spec empty_account?(t, EVM.address()) :: boolean()
  def empty_account?(t, address)

  @spec get_account_balance(t, EVM.address()) :: nil | EVM.Wei.t()
  def get_account_balance(t, address)

  @spec add_wei(t, EVM.address(), integer()) :: nil | EVM.Wei.t()
  def add_wei(t, address, value)

  @spec transfer(t, EVM.address(), EVM.address(), integer()) :: nil | EVM.Wei.t()
  def transfer(t, from, to, value)

  @spec get_account_code(t, EVM.address()) :: nil | binary()
  def get_account_code(t, address)

  @spec get_account_nonce(EVM.Interface.AccountInterface.t(), EVM.address()) :: integer()
  def get_account_nonce(mock_account_interface, address)

  @spec get_account_code_hash(t, EVM.address()) :: binary() | nil
  def get_account_code_hash(t, address)

  @spec increment_account_nonce(t, EVM.address()) :: {t(), integer()}
  def increment_account_nonce(t, address)

  @spec get_storage(t, EVM.address(), integer()) ::
          {:ok, integer()} | :account_not_found | :key_not_found
  def get_storage(t, address, key)

  @spec put_storage(t, EVM.address(), integer(), integer()) :: t
  def put_storage(t, address, key, value)

  @spec remove_storage(t(), EVM.address(), integer()) :: t()
  def remove_storage(t, address, key)

  @spec dump_storage(t) :: %{EVM.address() => EVM.val()}
  def dump_storage(t)

  @spec message_call(
          t,
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
        ) :: {t, EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  def message_call(
        t,
        sender,
        originator,
        recipient,
        contract,
        available_gas,
        gas_price,
        value,
        apparent_value,
        data,
        stack_depth,
        block_header
      )

  @spec create_contract(
          t,
          EVM.address(),
          EVM.address(),
          EVM.Gas.t(),
          EVM.Gas.gas_price(),
          EVM.Wei.t(),
          EVM.MachineCode.t(),
          integer(),
          Header.t(),
          EVM.address(),
          EVM.Configuration.t()
        ) :: {:ok | :error, {t, EVM.Gas.t(), EVM.SubState.t()}}
  def create_contract(
        t,
        sender,
        originator,
        available_gas,
        gas_price,
        endowment,
        init_code,
        stack_depth,
        block_header,
        new_account_address,
        config
      )

  @spec new_contract_address(t, EVM.address(), integer()) :: EVM.address()
  def new_contract_address(t, address, nonce)

  @doc "Sets the balance of the account at the given address to zero"
  @spec clear_balance(t, EVM.address()) :: t
  def clear_balance(t, address)
end
