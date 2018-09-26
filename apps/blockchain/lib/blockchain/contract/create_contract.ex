defmodule Blockchain.Contract.CreateContract do
  @moduledoc """
  Represents a contract creation command,
  as defined in Section 7, Eq.(76) of the Yellow Paper.
  """

  alias Blockchain.Interface.{BlockInterface, AccountInterface}
  alias Block.Header
  alias Blockchain.Account
  alias EVM.{SubState, Gas}

  defstruct account_interface: %AccountInterface{},
            sender: <<>>,
            originator: <<>>,
            available_gas: 0,
            gas_price: 0,
            endowment: 0,
            init_code: <<>>,
            stack_depth: 0,
            block_header: nil,
            new_account_address: nil,
            config: EVM.Configuration.Frontier.new()

  @typedoc """
  Yellow Paper Terms:

  - σ: state,
  - s: sender,
  - o: originator,
  - g: available_gas,
  - p: gas_price,
  - v: endowment,
  - i: init_code,
  - e: stack_depth
  """
  @type t :: %__MODULE__{
          account_interface: AccountInterface.t(),
          sender: EVM.address(),
          originator: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          endowment: EVM.Wei.t(),
          init_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_header: Header.t(),
          new_account_address: nil | EVM.address(),
          config: EVM.Configuration.t()
        }

  @spec execute(t()) :: {:ok | :error, {AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t()}}
  def execute(params) do
    original_account_interface = params.account_interface
    contract_address = new_account_address(params)
    {account, _} = AccountInterface.account(original_account_interface, contract_address)

    if is_nil(account) || Account.uninitialized_contract?(account) do
      result = {rem_gas, _, _, output} = create(params, contract_address)

      # From the Yellow Paper:
      # if the execution halts in an exceptional fashion
      # (i.e.  due to an exhausted gas supply, stack underflow, in-
      # valid jump destination or invalid instruction), then no gas
      # is refunded to the caller and the state is reverted to the
      # point immediately prior to balance transfer.
      #
      case output do
        :failed -> error(original_account_interface)
        {:revert, _} -> {:error, {original_account_interface, rem_gas, SubState.empty()}}
        _ -> finalize(result, params, contract_address)
      end
    else
      if account_will_collide?(account) do
        error(original_account_interface)
      else
        {:ok, {original_account_interface, 0, SubState.empty()}}
      end
    end
  end

  @spec increment_nonce_of_touched_account(
          AccountInterface.t(),
          EVM.Configuration.t(),
          EVM.address()
        ) :: AccountInterface.t()
  defp increment_nonce_of_touched_account(account_interface, config, address) do
    if EVM.Configuration.increment_nonce_on_create?(config) do
      AccountInterface.increment_account_nonce(account_interface, address)
    else
      account_interface
    end
  end

  @spec account_will_collide?(Account.t()) :: boolean()
  defp account_will_collide?(account) do
    account.nonce > 0 || !Account.is_simple_account?(account)
  end

  @spec error(AccountInterface.t()) :: {:error, {AccountInterface.t(), 0, SubState.t()}}
  defp error(account_interface) do
    {:error, {account_interface, 0, SubState.empty()}}
  end

  @spec create(t(), EVM.address()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  defp create(params, address) do
    account_interface =
      params
      |> init_account(address)
      |> increment_nonce_of_touched_account(params.config, address)

    # Create an execution environment for a create contract call.
    # This is defined in Eq.(88), Eq.(89), Eq.(90), Eq.(91), Eq.(92),
    # Eq.(93), Eq.(94) and Eq.(95) of the Yellow Paper.
    exec_env = %EVM.ExecEnv{
      address: address,
      originator: params.originator,
      gas_price: params.gas_price,
      data: <<>>,
      sender: params.sender,
      value_in_wei: params.endowment,
      machine_code: params.init_code,
      stack_depth: params.stack_depth,
      block_interface: BlockInterface.new(params.block_header, account_interface.state.db),
      account_interface: account_interface,
      config: params.config
    }

    EVM.VM.run(params.available_gas, exec_env)
  end

  @spec init_account(t, EVM.address()) :: AccountInterface.t()
  defp init_account(params, address) do
    {account, _code} = AccountInterface.account(params.account_interface, address)

    account_interface =
      if is_nil(account) do
        AccountInterface.reset_account(params.account_interface, address)
      else
        params.account_interface
      end

    AccountInterface.transfer_wei!(account_interface, params.sender, address, params.endowment)
  end

  @spec finalize(
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()},
          t(),
          EVM.address()
        ) :: {:ok | :error, {AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t()}}
  defp finalize({remaining_gas, accrued_sub_state, exec_env, output}, params, address) do
    original_account_interface = params.account_interface
    contract_creation_cost = creation_cost(output)
    insufficient_gas = remaining_gas < contract_creation_cost

    cond do
      insufficient_gas && EVM.Configuration.fail_contract_creation_lack_of_gas?(params.config) ->
        {:error, {original_account_interface, 0, SubState.empty()}}

      EVM.Configuration.limit_contract_code_size?(params.config, byte_size(output)) ->
        {:error, {original_account_interface, 0, SubState.empty()}}

      true ->
        modified_account_interface = exec_env.account_interface

        resultant_gas =
          if insufficient_gas do
            remaining_gas
          else
            remaining_gas - contract_creation_cost
          end

        resultant_account_interface =
          if insufficient_gas do
            modified_account_interface
          else
            AccountInterface.put_code(modified_account_interface, address, output)
          end

        sub_state = SubState.add_touched_account(accrued_sub_state, address)

        {:ok, {resultant_account_interface, resultant_gas, sub_state}}
    end
  end

  # Returns the additional cost after creating a new contract.
  # This is defined as Eq.(96) of the Yellow Paper.
  @spec creation_cost(binary()) :: EVM.Wei.t()
  defp creation_cost(output) do
    data_size =
      output
      |> :binary.bin_to_list()
      |> Enum.count()

    data_size * Gas.codedeposit_cost()
  end

  defp new_account_address(params) do
    if params.new_account_address do
      params.new_account_address
    else
      {sender_account, _} = AccountInterface.account(params.account_interface, params.sender)
      Account.Address.new(params.sender, sender_account.nonce)
    end
  end
end
