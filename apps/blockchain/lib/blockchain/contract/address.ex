defmodule Blockchain.Contract.Address do
  @moduledoc """
  Contract address functions and constants.
  """

  alias ExthCrypto.Hash.Keccak

  @size 160

  @doc """
  Determines the address of a new contract
  based on the sender and the sender's current nonce.

  This is defined as Eq.(77) in the Yellow Paper.

  Note: Nonce should be already pre-incremented when calling this function.

  ## Examples

      iex> Blockchain.Contract.Address.new(<<0x01::160>>, 1)
      <<82, 43, 50, 148, 230, 208, 106, 162, 90, 208, 241, 184, 137, 18, 66, 227, 53, 211, 180, 89>>

      iex> Blockchain.Contract.Address.new(<<0x01::160>>, 2)
      <<83, 91, 61, 122, 37, 47, 160, 52, 237, 113, 240, 197, 62, 192, 198, 247, 132, 203, 100, 225>>

      iex> Blockchain.Contract.Address.new(<<0x02::160>>, 3)
      <<30, 208, 147, 166, 216, 88, 183, 173, 67, 180, 70, 173, 88, 244, 201, 236, 9, 101, 145, 49>>
  """
  @spec new(EVM.address(), integer()) :: EVM.address()
  def new(sender, nonce) do
    [sender, nonce - 1]
    |> ExRLP.encode()
    |> Keccak.kec()
    |> BitHelper.mask_bitstring(@size)
  end
end
