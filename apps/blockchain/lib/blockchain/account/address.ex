defmodule Blockchain.Account.Address do
  @moduledoc """
  Represents an account's address. The address of the new account is defined as
  being the rightmost 160 bits of the Keccak hash of the RLP encoding of the 
  structure containing only the sender and the account nonce. 
  """

  alias ExthCrypto.Hash.Keccak

  @type t :: <<_::160>>
  @size 160
  @size_in_bytes 20

  @doc """
  Determines the address of a new contract
  based on the sender and the sender's current nonce. See Eq.(77) in the Yellow 
  Paper.

  **Note**: Nonce should be already pre-incremented when calling this function.

  ## Examples

      iex> Blockchain.Account.Address.new(<<0x01::160>>, 1)
      <<82, 43, 50, 148, 230, 208, 106, 162, 90, 208, 241, 184, 137, 18, 66, 227, 53, 211, 180, 89>>

      iex> Blockchain.Account.Address.new(<<0x01::160>>, 2)
      <<83, 91, 61, 122, 37, 47, 160, 52, 237, 113, 240, 197, 62, 192, 198, 247, 132, 203, 100, 225>>
  """
  @spec new(EVM.address(), integer()) :: t()
  def new(sender, nonce) do
    [sender, nonce - 1]
    |> ExRLP.encode()
    |> Keccak.kec()
    |> BitHelper.mask_bitstring(@size)
  end

  @spec from(binary() | integer()) :: t()
  def from(raw_address) when is_integer(raw_address) do
    raw_address
    |> :binary.encode_unsigned()
    |> from()
  end

  def from(raw_address) when is_binary(raw_address) do
    BitHelper.pad(raw_address, @size_in_bytes)
  end
end
