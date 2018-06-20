defmodule Blockchain.Transaction.Validation do
  @moduledoc """
  This module is responsible for transaction validation.
  This is specified in Section 6.2 of the Yellow Paper Eq.(65) and Eq.(66).
  """

  alias EthCore.Block.Header
  alias Blockchain.{Transaction, Account}
  alias Blockchain.Transaction.Signature

  # TODO: Consider returning a set of reasons, instead of a singular reason.

  @doc """
  Checks the validity of a transaction that is required to be
  true before we're willing to execute a transaction.
  """
  @spec validate(EVM.state(), Transaction.t(), Header.t()) :: :valid | {:invalid, atom()}
  def validate(state, tx, header) do
    case Signature.sender(tx) do
      {:error, _reason} ->
        {:invalid, :invalid_sender}

      {:ok, sender_address} ->
        case Account.get_account(state, sender_address) do
          nil -> {:invalid, :missing_account}
          sender -> validate_sender(sender, tx, header)
        end
    end
  end

  @spec validate_sender(Account.t(), Transaction.t(), Header.t()) :: :valid | {:invalid, atom()}
  defp validate_sender(sender, tx, header) do
    g_0 = Transaction.intrinsic_gas_cost(tx, header)
    v_0 = tx.gas_limit * tx.gas_price + tx.value

    cond do
      sender.nonce != tx.nonce -> {:invalid, :nonce_mismatch}
      g_0 > tx.gas_limit -> {:invalid, :insufficient_intrinsic_gas}
      v_0 > sender.balance -> {:invalid, :insufficient_balance}
      tx.gas_limit > Header.available_gas(header) -> {:invalid, :over_gas_limit}
      true -> :valid
    end
  end
end
