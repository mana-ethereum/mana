defmodule Blockchain.Contract do
  @moduledoc """
  Defines functions on create and making message calls
  to contracts. The core of the module is to implement
  Λ and Θ, as defined in Eq.(62) and described in detail
  in sections 7 and 8 of the Yellow Paper.
  """

  alias Blockchain.Account
  alias Blockchain.Contract.{CreateContract, MessageCall}

  @doc """
  Creates a new contract,
  as defined in Section 7 Eq.(81) and Eq.(87) of the Yellow Paper as Λ.

  We are also inlining Eq.(97) and Eq.(98).
  """
  @spec create(CreateContract.t()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t()}
  def create(params), do: CreateContract.execute(params)

  @doc """
  Executes a message call to a contract,
  defiend in Section 8 Eq.(99) of the Yellow Paper as Θ.

  We are also inlining Eq.(105).
  """
  @spec message_call(MessageCall.t()) ::
          {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  def message_call(params), do: MessageCall.execute(params)

  @doc """
  Creates a blank contract prior to initialization code
  being run and sets its nonce to 1, as defined in Eq.(78-82) of the Yellow Paper.
  """
  @spec create_blank(EVM.state(), EVM.address(), EVM.address(), EVM.Wei.t(), integer()) ::
          EVM.state()
  def create_blank(state, contract_address, sender_address, endowment, nonce) do
    state
    |> Account.put_account(contract_address, %Account{nonce: nonce})
    |> Account.transfer!(sender_address, contract_address, endowment)
  end
end
