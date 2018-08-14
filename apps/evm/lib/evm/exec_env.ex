defmodule EVM.ExecEnv do
  alias EVM.Interface.{AccountInterface, BlockInterface}
  alias EVM.Configuration

  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

  We've added our interfaces for interacting with contracts
  and accounts to this struct as well.

  This generally relates to `I` in the Yellow Paper, defined in Section 9.3.
  """

  defstruct address: nil,
            originator: nil,
            gas_price: nil,
            data: nil,
            sender: nil,
            value_in_wei: nil,
            machine_code: <<>>,
            stack_depth: 0,
            account_interface: nil,
            block_interface: nil,
            config: EVM.Configuration.Frontier.new(),
            created_accounts: [],
            initial_account_interface: nil

  @typedoc """
  Terms from Yellow Paper:

  - I_a: address
  - I_o: originator
  - I_p: gas_price
  - I_d: data
  - I_s: sender
  - I_v: value_in_wei
  - I_b: machine_code
  - I_e: stack_depth
  - I_h (wrapped in interface): account_interface
  """
  @type t :: %__MODULE__{
          address: EVM.address(),
          originator: EVM.address(),
          gas_price: EVM.Gas.gas_price(),
          data: binary(),
          sender: EVM.address(),
          value_in_wei: EVM.Wei.t(),
          machine_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_interface: BlockInterface.t(),
          account_interface: AccountInterface.t(),
          config: Configuration.t(),
          created_accounts: [EVM.address()]
        }

  @spec put_storage(t(), integer(), integer()) :: t()
  def put_storage(
        exec_env = %{account_interface: account_interface, address: address},
        key,
        value
      ) do
    account_interface = AccountInterface.put_storage(account_interface, address, key, value)

    Map.put(exec_env, :account_interface, account_interface)
  end

  @spec get_storage(t(), integer()) :: atom() | {:ok, integer()}
  def get_storage(%{account_interface: account_interface, address: address}, key) do
    AccountInterface.get_storage(account_interface, address, key)
  end

  @spec remove_storage(t(), integer()) :: t()
  def remove_storage(exec_env = %{account_interface: account_interface, address: address}, key) do
    account_interface = AccountInterface.remove_storage(account_interface, address, key)

    Map.put(exec_env, :account_interface, account_interface)
  end

  @spec clear_account_balance(t()) :: t()
  def clear_account_balance(exec_env = %{account_interface: account_interface, address: address}) do
    account_interface = AccountInterface.clear_balance(account_interface, address)

    Map.put(exec_env, :account_interface, account_interface)
  end

  @spec transfer_balance_to(t(), EVM.Address.t()) :: t()
  def transfer_balance_to(exec_env, to) do
    %{account_interface: account_interface, address: address} = exec_env

    balance = AccountInterface.get_account_balance(account_interface, address)

    transfer_wei_to(exec_env, to, balance)
  end

  @spec transfer_wei_to(t(), EVM.Address.t(), integer()) :: t()
  def transfer_wei_to(exec_env, to, value) do
    account_interface =
      AccountInterface.transfer(exec_env.account_interface, exec_env.address, to, value)

    %{exec_env | account_interface: account_interface}
  end

  @spec new_account?(t(), EVM.Address.t()) :: boolean()
  def new_account?(exec_env, address) do
    Enum.member?(exec_env.created_accounts, address) ||
      !AccountInterface.account_exists?(
        exec_env.initial_account_interface,
        address
      )
  end

  @spec add_created_address(t(), integer()) :: t()
  def add_created_address(exec_env, address) do
    address = :binary.encode_unsigned(address)

    %{exec_env | created_accounts: [address | exec_env.created_accounts]}
  end
end
