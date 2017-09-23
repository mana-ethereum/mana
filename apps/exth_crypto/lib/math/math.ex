defmodule ExCrypto.Math do
  @moduledoc """
  Helpers for basic math functions.
  """

  @doc """
  Simple function to compute modulo function to work on integers of any sign.

  ## Examples

      iex> ExCrypto.Math.mod(5, 2)
      1

      iex> ExCrypto.Math.mod(-5, 1337)
      1332

      iex> ExCrypto.Math.mod(1337 + 5, 1337)
      5

      iex> ExCrypto.Math.mod(0, 1337)
      0
  """
  def mod(x, n) when x > 0, do: rem x, n
  def mod(x, n) when x < 0, do: rem n + x, n
  def mod(0, _n), do: 0

end