defmodule EVM.ExecEnv do
  alias EVM.Interface.AccountInterface
  alias EVM.{Configuration, BlockHeaderInfo}

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
            block_header_info: nil,
            config: Configuration.Frontier.new(),
            static: false

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
  - I_H (via a behaviour): block_header info
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
          block_header_info: BlockHeaderInfo.t(),
          account_interface: AccountInterface.t(),
          config: Configuration.t(),
          static: boolean()
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

  @spec get_initial_storage(t(), integer()) :: atom() | {:ok, integer()}
  def get_initial_storage(%{account_interface: account_interface, address: address}, key) do
    AccountInterface.get_initial_storage(account_interface, address, key)
  end

  @spec get_balance(t()) :: EVM.Wei.t()
  def get_balance(%{account_interface: account_interface, address: address}) do
    AccountInterface.get_account_balance(account_interface, address)
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

  @spec non_existent_account?(t(), EVM.Address.t()) :: boolean()
  def non_existent_account?(exec_env, address) do
    !AccountInterface.account_exists?(
      exec_env.account_interface,
      address
    )
  end

  @spec non_existent_or_empty_account?(t(), EVM.Address.t()) :: boolean()
  def non_existent_or_empty_account?(exec_env, address) do
    is_empty_account = AccountInterface.empty_account?(exec_env.account_interface, address)

    is_empty_account || non_existent_account?(exec_env, address)
  end
end
