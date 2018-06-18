defmodule EVM.Address do
  @moduledoc """
  EVM address functions and constants.
  """

  alias ExthCrypto.Hash.Keccak

  @size 20
  @max round(:math.pow(2, @size * EVM.byte_size()))

  @doc """
  Returns the maximum allowed address size.
  """
  @spec size() :: integer()
  def size(), do: @size

  @doc """
  Returns the maximum allowed address value.
  """
  @spec max() :: integer()
  def max(), do: @max

  @doc """
  Returns an address given an integer.
  """
  @spec new(integer()) :: binary()
  def new(address) when is_number(address) do
    address
    |> :binary.encode_unsigned()
    |> EVM.Helpers.left_pad_bytes(@size)
    |> EVM.Helpers.take_n_last_bytes(@size)
  end

  def new(address), do: address

  @doc """
  Returns an address given an address and a nonce.
  """
  @spec new(integer(), integer()) :: non_neg_integer()
  def new(address, nonce) do
    [address, nonce]
    |> ExRLP.encode()
    |> Keccak.kec()
    |> EVM.Helpers.take_n_last_bytes(@size)
    |> :binary.decode_unsigned()
  end

  @doc """
  Returns an address given a private key
  ## Examples

  iex> private_key = <<69, 169, 21, 228, 208, 96, 20, 158, 180, 54, 89, 96, 230, 167, 164, 95, 51, 67, 147, 9, 48, 97, 17, 107, 25, 126, 50, 64, 6, 95, 242, 216>>
  iex> EVM.Address.new_from_private_key(private_key)
  <<183, 161, 2, 91, 175, 48, 3, 246, 115, 36, 48, 226, 12, 217, 183, 109, 149, 51, 145, 179>>
  """
  @spec new_from_private_key(binary()) :: binary()
  def new_from_private_key(private_key) do
    ExthCrypto.Signature.get_public_key(private_key)
    |> elem(1)
    |> EVM.Helpers.take_n_last_bytes(@size)
  end
end
