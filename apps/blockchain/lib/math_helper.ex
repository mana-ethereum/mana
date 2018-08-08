defmodule Blockchain.MathHelper do
  alias Blockchain.Transaction

  @doc """
  Calculates the amount amount of gas to refund based on the final usage of the current transaction. This includes the remaining gas plus refunds from clearing storage.

  The specs calls for capping the refund at half of the total amount of gas used.

  This function is defined as `g*` in Eq.(65) in the Yellow Paper.

  ## Examples

      iex> Blockchain.MathHelper.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 5)
      15

      iex> Blockchain.MathHelper.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 99)
      55

      iex> Blockchain.MathHelper.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 10, 0)
      10

      iex> Blockchain.MathHelper.calculate_total_refund(%Blockchain.Transaction{gas_limit: 100}, 11, 99)
      55
  """
  @spec calculate_total_refund(Transaction.t(), EVM.Gas.t(), EVM.SubState.refund()) :: EVM.Gas.t()
  def calculate_total_refund(trx, remaining_gas, refund) do
    # T_g - trx.gas_limit
    # g' - remaining_gas
    # A'_r - refund
    max_refund = round(Float.floor((trx.gas_limit - remaining_gas) / 2))

    remaining_gas + min(max_refund, refund)
  end
end
