defmodule EVM.ExecEnv do
  alias EVM.Interface.{AccountInterface, BlockInterface}

  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

  We've added our interfaces for interacting with contracts
  and accounts to this struct as well.

  This generally relates to `I` in the Yellow Paper, defined in Section 9.3.
  """
  # I_a
  defstruct address: nil,
            # I_o
            originator: nil,
            # I_p
            gas_price: nil,
            # I_d
            data: nil,
            # I_s
            sender: nil,
            # I_v
            value_in_wei: nil,
            # I_b
            machine_code: <<>>,
            # I_e
            stack_depth: 0,
            # I_h (wrapped in interface)
            account_interface: nil,
            block_interface: nil

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
          account_interface: AccountInterface.t()
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

  @spec get_storage(t(), integer()) :: integer()
  def get_storage(%{account_interface: account_interface, address: address}, key) do
    AccountInterface.get_storage(account_interface, address, key)
  end

  @spec destroy_account(t()) :: t()
  def destroy_account(exec_env = %{account_interface: account_interface, address: address}) do
    account_interface = AccountInterface.destroy_account(account_interface, address)
    Map.put(exec_env, :account_interface, account_interface)
  end

  def transfer_wei_to(exec_env, to, value) do
    account_interface =
      AccountInterface.transfer(exec_env.account_interface, exec_env.address, to, value)

    %{exec_env | account_interface: account_interface}
  end
end
