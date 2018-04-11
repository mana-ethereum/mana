defmodule EVM.Address do
  @moduledoc """
  EVM address functions and constants.
  """
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
  def new(address) do
    address
    |> :binary.encode_unsigned()
    |> EVM.Helpers.left_pad_bytes(@size)
  end

  @doc """
  Returns an address given an address and a nonce.
  """
  @spec new(integer(), integer()) :: binary()
  def new(address, nonce) do
    ExRLP.encode([address, nonce])
    |> :keccakf1600.sha3_256()
    |> EVM.Helpers.take_n_last_bytes(@size)
    |> :binary.decode_unsigned()
  end
end
