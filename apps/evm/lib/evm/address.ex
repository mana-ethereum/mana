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

  @doc """
  Returns an address given a public key
  ## Examples

  iex> public_key = <<10, 28, 245, 65, 252, 131, 183, 183, 27, 137, 77, 25, 249, 162, 127, 77, 93, 22, 21, 97, 93, 195, 129, 41, 51, 14, 17, 86, 11, 19, 64, 44, 253, 90, 22, 87, 80, 52, 63, 50, 56, 190, 61, 187, 37, 157, 149, 39, 206, 145, 176, 29, 47, 68, 2, 177, 88, 132, 156, 160, 39, 29, 156, 188>>
  iex> EVM.Address.new_from_public_key(public_key)
  <<250, 252, 98, 50, 69, 173, 209, 14, 110, 229, 201, 136, 108, 45, 20, 50, 147, 102, 120, 66>>
  """
  @spec new_from_public_key(binary()) :: binary()
  def new_from_public_key(public_key) do
    public_key
    |> Keccak.kec()
    |> EVM.Helpers.take_n_last_bytes(@size)
  end
end
