defmodule Blockchain.Contract.CreateContract do
  @moduledoc """
  Represents a contract creation command,
  as defined in Section 7, Eq.(76) of the Yellow Paper.
  """

  alias Blockchain.Interface.{BlockInterface, AccountInterface}
  alias EthCore.Block.Header
  alias Blockchain.Contract.Address
  alias Blockchain.{Account, Contract}

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
            block_header: nil

  @type t :: %__MODULE__{
          state: EVM.state(),
          sender: EVM.address(),
          originator: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          endowment: EVM.Wei.t(),
          init_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_header: Header.t()
        }

  # TODO: Block header? "I_H has no special treatment and is determined from the blockchain"
  # TODO: Do we need to break this function up further?
  @spec execute(t()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  def execute(params) do
    sender_account = Account.get_account(params.state, params.sender)
    contract_address = Address.new(params.sender, sender_account.nonce)

    state_with_blank_contract =
      Contract.create_blank(
        params.state,
        contract_address,
        params.sender,
        params.endowment
      )

    exec_env = prepare_exec_env(contract_address, params, state_with_blank_contract)

    {remaining_gas, accrued_sub_state, exec_env, output} =
      EVM.VM.run(params.available_gas, exec_env)

    state_after_init = exec_env.account_interface.state

    if output != :failed do
      contract_creation_cost = creation_cost(output)

      insufficient_gas_before_homestead =
        remaining_gas < contract_creation_cost and
          params.block_header.number < Header.homestead()

      resultant_gas =
        cond do
          state_after_init == nil -> 0
          insufficient_gas_before_homestead -> remaining_gas
          true -> remaining_gas - contract_creation_cost
        end

      resultant_state =
        cond do
          state_after_init == nil ->
            params.state

          insufficient_gas_before_homestead ->
            state_after_init

          true ->
            Account.put_code(state_after_init, contract_address, output)
        end

      {resultant_state, resultant_gas, accrued_sub_state}
    else
      {params.state, params.available_gas, %EVM.SubState{}}
    end
  end

  @doc """
  Returns the additional cost after creating a new contract.

  This is defined as Eq.(96) of the Yellow Paper.

  # TODO: Implement and examples
  """
  @spec creation_cost(binary()) :: EVM.Wei.t()
  def creation_cost(_output), do: 0

  # Create an execution environment for a create contract call.
  # This is defined in Eq.(88), Eq.(89), Eq.(90), Eq.(91), Eq.(92),
  # Eq.(93), Eq.(94) and Eq.(95) of the Yellow Paper.
  defp prepare_exec_env(contract_address, params, state) do
    %EVM.ExecEnv{
      address: contract_address,
      originator: params.originator,
      gas_price: params.gas_price,
      data: <<>>,
      sender: params.sender,
      value_in_wei: params.endowment,
      machine_code: params.init_code,
      stack_depth: params.stack_depth,
      block_interface: BlockInterface.new(params.block_header, state.db),
      account_interface: AccountInterface.new(state)
    }
  end
end
