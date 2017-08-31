defmodule EVM.Helpers do
  @word_size 32
  @moduledoc """
  Various helper functions with no other home.
  """

  require Logger
  use Bitwise

  @doc """
  Inverts a map so each key becomes a value,
  and vice versa.

  ## Examples

      iex> EVM.Helpers.invert(%{a: 5, b: 10})
      %{5 => :a, 10 => :b}

      iex> EVM.Helpers.invert(%{dog: "cat"})
      %{"cat" => :dog}

      iex> EVM.Helpers.invert(%{cow: :moo})
      %{moo: :cow}

      iex> EVM.Helpers.invert(%{"name" => "bob"})
      %{"bob" => "name"}

      iex> EVM.Helpers.invert(%{})
      %{}
  """
  @spec invert(map()) :: map()
  def invert(m) do
    m
      |> Enum.into([])
      |> Enum.map(fn {a, b} -> {b, a} end)
      |> Enum.into(%{})
  end

  @doc """
  Gets the byte at position `pos` in binary.

  ## Examples

      iex> EVM.Helpers.binary_get(<<1, 2, 3, 4>>, 2)
      3

      iex> EVM.Helpers.binary_get(<<1, 2, 3, 4>>, 4)
      ** (ArgumentError) argument error
  """
  @spec binary_get(binary(), integer()) :: integer()
  def binary_get(binary, pos) do
    binary |> :binary.part(pos, 1) |> :binary.first
  end

  def bit_at(n, at), do: band((bsr(n, at)), 1)
  def bit_position(byte_position), do: byte_position * 8  + 7

  @doc """
  Gets the word size of a value or returns 0 if the value is 0

  ## Examples

      iex> EVM.Helpers.word_size(<<7::256>>)
      1

      iex> EVM.Helpers.word_size(for val <- 1..256, into: <<>>, do: <<val>>)
      8
  """
  @spec word_size(binary()) :: integer()
  def word_size(n) do
    round(:math.ceil(byte_size(n) / @word_size))
  end

  @doc """
  Wrap ints greater than the max int around back to 0

  ## Examples

      iex> EVM.Helpers.wrap_int(1)
      1

      iex> EVM.Helpers.wrap_int(EVM.max_int() + 1)
      1
  """
  @spec wrap_int(integer()) :: EVM.val
  def wrap_int(n) when n > 0, do: band(n, EVM.max_int() - 1)
  def wrap_int(n), do: n

  @doc """
  Encodes signed ints using twos compliment

  ## Examples

      iex> EVM.Helpers.encode_signed(1)
      1

      iex> EVM.Helpers.encode_signed(-1)
      EVM.max_int() - 1
  """
  @spec encode_signed(integer()) :: EVM.val
  def encode_signed(n) when n < 0, do: EVM.max_int() - abs(n)
  def encode_signed(n), do: n

  @spec decode_signed(integer()) :: EVM.val
  def decode_signed(n) when is_integer(n) do
    decode_signed(:binary.encode_unsigned(n))
  end

  def decode_signed(n) when is_binary(n) do
    <<sign :: size(1), _ :: bitstring>> = n

    if sign == 0 do
        :binary.decode_unsigned(n)
      else
        :binary.decode_unsigned(n) - EVM.max_int()
    end
  end

  @doc """
  Helper function to print an instruction message.
  """
  def inspect(msg, prefix) do
    Logger.debug(inspect [prefix, ":", msg])

    msg
  end
end
