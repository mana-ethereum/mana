defmodule MathHelper do
  @moduledoc """
  Simple functions to help with common
  math functions.
  """

  @doc """
  Simple floor function that makes sure
  we return an integer type.

  ## Examples

      iex> MathHelper.floor(3.5)
      3

      iex> MathHelper.floor(-3.5)
      -4

      iex> MathHelper.floor(5)
      5
  """
  @spec floor(number()) :: integer()
  def floor(x), do: round(:math.floor(x))

  @doc """
  Simple helper to calculate a log in any
  given base. E.g. the `log_15(30)`, which
  would be expressed at `MathHelper.log(30, 15)`.

  ## Examples

      iex> MathHelper.log(225, 15)
      2.0

      iex> MathHelper.log(240, 15)
      2.0238320992392618

      iex> MathHelper.log(1024, 10)
      3.0102999566398116

      iex> MathHelper.log(999999, 9999)
      1.500016178459417
  """
  @spec log(number(), number()) :: number()
  def log(x, b), do: :math.log(x) / :math.log(b)
end