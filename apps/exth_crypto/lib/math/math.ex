defmodule ExCrypto.Math do
  @moduledoc """
  Helpers for basic math functions.
  """

  @doc """
  Simple wrapper around the modulo function to work on integers.

  ## Examples

      iex> ExCrypto.Math.mod(5, 2)
      1

      iex> ExCrypto.Math.mod(1337 + 5, 1337)
      5
  """
  def mod(x, n) do
    round(:math.mod(x, n))
  end

end