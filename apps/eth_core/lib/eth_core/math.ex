defmodule EthCore.Math do
  @moduledoc """
  Simple functions to help with common math functions.
  """

  alias EthCore.Config

  @doc """
  Simple floor function that makes sure
  we return an integer type.

  ## Examples

      iex> EthCore.Math.floor(3.5)
      3

      iex> EthCore.Math.floor(-3.5)
      -4

      iex> EthCore.Math.floor(5)
      5
  """
  @spec floor(number()) :: integer()
  def floor(x), do: x |> :math.floor() |> round()

  @doc """
  Simple round function.

  ## Examples

      iex> EthCore.Math.round_int(3.5)
      3

      iex> EthCore.Math.round_int(-3.5)
      -3

      iex> EthCore.Math.round_int(-0.5)
      0
  """
  @spec round_int(number()) :: integer()
  def round_int(n) when n < 0, do: n |> :math.ceil() |> round()
  def round_int(n), do: n |> :math.floor() |> round()

  @doc """
  Simple helper to calculate a log in any
  given base. E.g. the `log_15(30)`, which
  would be expressed at `EthCore.Math.log(30, 15)`.

  ## Examples

      iex> EthCore.Math.log(225, 15)
      2.0

      iex> EthCore.Math.log(240, 15)
      2.0238320992392618

      iex> EthCore.Math.log(1024, 10)
      3.0102999566398116

      iex> EthCore.Math.log(999999, 9999)
      1.500016178459417
  """
  @spec log(number(), number()) :: number()
  def log(x, b), do: :math.log(x) / :math.log(b)

  @doc """
  Returns the byte size of an integer

  ## Examples

      iex> EthCore.Math.integer_byte_size(0)
      0

      iex> EthCore.Math.integer_byte_size(1)
      1

      iex> EthCore.Math.integer_byte_size(0xfffffffff)
      5
  """
  @spec integer_byte_size(number()) :: number()
  def integer_byte_size(n) when n == 0, do: 0
  def integer_byte_size(n), do: n |> :binary.encode_unsigned() |> byte_size()

  @doc """
  Bits to words

  ## Examples

      iex> EthCore.Math.bits_to_words(0)
      0

      iex> EthCore.Math.bits_to_words(9)
      1

      iex> EthCore.Math.bits_to_words(256)
      8
  """
  @spec bits_to_words(number()) :: number()
  def bits_to_words(n) do
    (n / Config.word_size())
    |> :math.ceil()
    |> round()
  end
end
