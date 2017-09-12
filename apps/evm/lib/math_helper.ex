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
  Simple round function

  ## Examples

      iex> MathHelper.round_int(3.5)
      3
      iex> MathHelper.round_int(-3.5)
      -3
      iex> MathHelper.round_int(-0.5)
      0
  """
  @spec floor(number()) :: integer()
  def round_int(n) when n < 0, do: round(:math.ceil(n))
  def round_int(n), do: round(:math.floor(n))

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

  @doc """
  Returns the byte size of an integer

  ## Examples

      iex> MathHelper.integer_byte_size(0)
      0

      iex> MathHelper.integer_byte_size(1)
      1

      iex> MathHelper.integer_byte_size(0xfffffffff)
      5

  """
  @spec integer_byte_size(number()) :: number()
  def integer_byte_size(n) when n == 0, do: 0
  def integer_byte_size(n), do: byte_size(:binary.encode_unsigned(n))

  @doc """
  Bits to words

  ## Examples

      iex> MathHelper.bits_to_words(0)
      0

      iex> MathHelper.bits_to_words(9)
      1

      iex> MathHelper.bits_to_words(256)
      8

  """
  @spec bits_to_words(number()) :: number()
  def bits_to_words(n), do: round(:math.ceil(n / EVM.word_size()))
end
