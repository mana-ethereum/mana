defmodule Blockchain.Contract.CreateContract do
  @moduledoc """
  Represents a contract creation command,
  as defined in Section 7, Eq.(76) of the Yellow Paper.
  """

  alias Blockchain.Interface.{BlockInterface, AccountInterface}
  alias Block.Header
  alias Blockchain.Contract.Address
  alias Blockchain.{Account, Contract}
  alias EVM.{SubState, Gas}

  # σ
  defstruct state: %{},
            # s
            sender: <<>>,
            # o
            originator: <<>>,
            # g
            available_gas: 0,
            # p
            gas_price: 0,
            # v
            endowment: 0,
            # i
            init_code: <<>>,
            # e
            stack_depth: 0,
            block_header: nil,
            config: EVM.Configuration.Frontier.new()

  @type t :: %__MODULE__{
          state: EVM.state(),
          sender: EVM.address(),
          originator: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          endowment: EVM.Wei.t(),
          init_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_header: Header.t(),
          config: EVM.Configuration.t()
        }

  # TODO: Block header? "I_H has no special treatment and is determined from the blockchain"
  @spec execute(t()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  def execute(params) do
    sender_account = Account.get_account(params.state, params.sender)
    contract_address = Address.new(params.sender, sender_account.nonce)

    if account_exists?(params, contract_address) do
      account = Account.get_account(params.state, contract_address)

      # params.stack_depth != 0 means that we're not in contract creation transaction
      # because `create` evm instruction should have parameters on the stack that are pushed to it so
      # it never is zero
      if account.nonce == 0 && Account.is_simple_account?(account) && params.stack_depth != 0 do
        {:ok, {params.state, params.available_gas, SubState.empty()}}
      else
        {:ok, {params.state, 0, SubState.empty()}}
      end
    else
      result = {_, _, _, output} = create(params, contract_address)

      # From the Yellow Paper:
      # if the execution halts in an exceptional fashion
      # (i.e.  due to an exhausted gas supply, stack underflow, in-
      # valid jump destination or invalid instruction), then no gas
      # is refunded to the caller and the state is reverted to the
      # point immediately prior to balance transfer.
      if output == :failed do
        {:error, {params.state, 0, SubState.empty()}}
      else
        finalize(result, params, contract_address)
      end
    end
  end

  @spec account_exists?(t(), EVM.address()) :: boolean()
  defp account_exists?(params, address) do
    account = Account.get_account(params.state, address)

    !(is_nil(account) || Account.empty?(account))
  end

  @spec create(t(), EVM.address()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  defp create(params, address) do
    state_with_blank_contract =
      Contract.create_blank(
        params.state,
        address,
        params.sender,
        params.endowment
      )

    account_interface = AccountInterface.new(state_with_blank_contract)

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
      block_interface: BlockInterface.new(params.block_header, state_with_blank_contract.db),
      account_interface: account_interface,
      initial_account_interface: account_interface,
      config: params.config
    }

    EVM.VM.run(params.available_gas, exec_env)
  end

  @spec finalize(
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()},
          t(),
          EVM.address()
        ) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  defp finalize({remaining_gas, accrued_sub_state, exec_env, output}, params, address) do
    state_after_init = exec_env.account_interface.state

    contract_creation_cost = creation_cost(output)
    insufficient_gas = remaining_gas < contract_creation_cost

    cond do
      insufficient_gas && EVM.Configuration.fail_contract_creation_lack_of_gas?(params.config) ->
        {:error, {params.state, 0, SubState.empty()}}

      # EIP170 https://github.com/ethereum/EIPs/blob/master/EIPS/eip-170.md
      byte_size(output) > 24_577 ->
        {:error, {params.state, 0, SubState.empty()}}

      true ->
        resultant_gas =
          if insufficient_gas do
            remaining_gas
          else
            remaining_gas - contract_creation_cost
          end

        resultant_state =
          if insufficient_gas do
            state_after_init
          else
            Account.put_code(state_after_init, address, output)
          end

        {:ok, {resultant_state, resultant_gas, accrued_sub_state}}
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
end
