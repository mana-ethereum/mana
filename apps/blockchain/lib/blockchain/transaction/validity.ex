defmodule Blockchain.Transaction.Validity do
  @moduledoc """
  This module is responsible for transaction validation,
  as defined in the Yellow Paper.
  """

  alias Block.Header
  alias Blockchain.{Account, Chain, Transaction}
  alias EVM.Configuration
  alias MerklePatriciaTree.Trie

  @doc """
  Validates the validity of a transaction that is required to be
  true before we're willing to execute a transaction. This is
  specified in Section 6.2 of the Yellow Paper Eq.(65) and Eq.(66).
  """
  @spec validate(Trie.t(), Transaction.t(), Block.Header.t(), Chain.t()) ::
          :valid | {:invalid, atom()}
  def validate(state, trx, block_header, chain) do
    evm_config = Chain.evm_config(chain, block_header.number)

    with :ok <- validate_signature(trx, chain, evm_config),
         {:ok, sender_address} <- Transaction.Signature.sender(trx, chain.params.network_id) do
      errors =
        []
        |> check_intristic_gas(trx, evm_config)
        |> check_account_validity(trx, state, sender_address)
        |> check_gas_limit(trx, block_header)

      if errors == [], do: :valid, else: {:invalid, errors}
    end
  end

  defp check_account_validity(errors, trx, state, sender_address) do
    sender_account = Account.get_account(state, sender_address)

    if sender_account do
      errors
      |> check_sender_nonce(trx, sender_account)
      |> check_balance(trx, sender_account)
    else
      errors
    end
  end

  defp validate_signature(trx, chain, evm_config) do
    max_s_value = evm_config.max_signature_s

    if Transaction.Signature.is_signature_valid?(trx.r, trx.s, trx.v, chain.params.network_id,
         max_s: max_s_value
       ) do
      :ok
    else
      {:invalid, :invalid_sender}
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

  @spec check_intristic_gas([], Transaction.t(), Configuration.t()) ::
          [] | [:insufficient_intrinsic_gas]
  defp check_intristic_gas(errors, transaction, config) do
    intrinsic_gas_cost = Transaction.intrinsic_gas_cost(transaction, config)

    if intrinsic_gas_cost > transaction.gas_limit do
      [:insufficient_intrinsic_gas | errors]
    else
      errors
    end
  end

  @spec check_balance(
          [:insufficient_intrinsic_gas | :nonce_mismatch],
          Transaction.t(),
          Account.t()
        ) :: [:insufficient_balance | :insufficient_intrinsic_gas | :nonce_mismatch]
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
