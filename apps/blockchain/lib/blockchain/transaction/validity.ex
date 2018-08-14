defmodule Blockchain.Transaction.Validity do
  @moduledoc """
  This module is responsible for transaction validation,
  as defined in the Yellow Paper.
  """

  alias Blockchain.{Account, Transaction}
  alias Block.Header

  @doc """
  Validates the validity of a transaction that is required to be
  true before we're willing to execute a transaction. This is
  specified in Section 6.2 of the Yellow Paper Eq.(65) and Eq.(66).
  """
  @spec validate(EVM.state(), Transaction.t(), Block.Header.t(), EVM.Configuration.t()) ::
          :valid | {:invalid, atom()}
  def validate(state, trx, block_header, config) do
    with :ok <- validate_signature(trx, config),
         {:ok, sender_address} <- Transaction.Signature.sender(trx),
         {:ok, sender_account} <- retrieve_account(state, sender_address) do
      errors =
        []
        |> check_sender_nonce(trx, sender_account)
        |> check_intristic_gas(trx, config)
        |> check_balance(trx, sender_account)
        |> check_gas_limit(trx, block_header)

      if errors == [], do: :valid, else: {:invalid, errors}
    end
  end

  @spec validate_signature(Transaction.t(), EVM.Configuration.t()) ::
          :ok | {:invalid, :invalid_signature}
  defp validate_signature(trx, config) do
    max_s_value = EVM.Configuration.max_signature_s(config)

    if Transaction.Signature.is_signature_valid?(trx.r, trx.s, trx.v, max_s: max_s_value) do
      :ok
    else
      {:invalid, :invalid_sender}
    end
  end

  @spec retrieve_account(EVM.state(), EVM.address()) ::
          {:ok, Account.t()} | {:invalid, :missing_account}
  defp retrieve_account(state, sender_address) do
    case Account.get_account(state, sender_address) do
      nil ->
        {:invalid, :missing_account}

      sender_account ->
        {:ok, sender_account}
    end
  end

  @spec check_sender_nonce([atom()], Transaction.t(), Account.t()) :: [atom()]
  defp check_sender_nonce(errors, transaction, account) do
    if account.nonce != transaction.nonce do
      [:nonce_mismatch | errors]
    else
      errors
    end
  end

  @spec check_intristic_gas([atom()], Transaction.t(), EVM.Configuration.t()) :: [atom()]
  defp check_intristic_gas(errors, transaction, config) do
    intrinsic_gas_cost = Transaction.intrinsic_gas_cost(transaction, config)

    if intrinsic_gas_cost > transaction.gas_limit do
      [:insufficient_intrinsic_gas | errors]
    else
      errors
    end
  end

  @spec check_balance([atom()], Transaction.t(), Account.t()) :: [atom()]
  defp check_balance(errors, transaction, account) do
    value = transaction.gas_limit * transaction.gas_price + transaction.value

    if value > account.balance do
      [:insufficient_balance | errors]
    else
      errors
    end
  end

  @spec check_gas_limit([atom()], Transaction.t(), Block.Header.t()) :: [atom()]
  defp check_gas_limit(errors, transaction, header) do
    if transaction.gas_limit > Header.available_gas(header) do
      [:over_gas_limit | errors]
    else
      errors
    end
  end
end
