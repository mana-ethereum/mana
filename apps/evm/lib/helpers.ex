defmodule EVM.Helpers do
  @moduledoc """
  Various helper functions with no other home.
  """

  require Logger
  use Bitwise
  alias EVM.Address

  @max_uint_255 round(:math.pow(2, 255)) - 1
  @max_256_ceiling round(:math.pow(2, 256))

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
    Enum.into(m, %{}, fn {a, b} -> {b, a} end)
  end

  def bit_at(n, at), do: band(bsr(n, at), 1)
  def bit_position(byte_position), do: byte_position * 8 + 7

  @doc """
  Wrap ints greater than the max int around back to 0

  ## Examples

      iex> EVM.Helpers.wrap_int(1)
      1

      iex> EVM.Helpers.wrap_int(EVM.max_int() + 1)
      1
  """
  @spec wrap_int(integer()) :: EVM.val()
  def wrap_int(n) when n > 0, do: band(n, EVM.max_int() - 1)
  def wrap_int(n), do: n

  @doc """
  Wrap ints greater than the maximum allowed address size.

  ## Examples

      iex> EVM.Helpers.wrap_address(1)
      1

      iex> EVM.Helpers.wrap_address(<<1>>)
      <<1>>

      iex> EVM.Helpers.wrap_address(EVM.Address.max() + 1)
      1
  """
  def wrap_address(n) when is_integer(n), do: band(n, Address.max() - 1)

  def wrap_address(n) when is_binary(n) do
    if byte_size(n) > Address.size() do
      :binary.part(n, 0, Address.size())
    else
      n
    end
  end

  @doc """
  Encodes signed ints using twos compliment

  ## Examples

      iex> EVM.Helpers.encode_signed(1)
      1

      iex> EVM.Helpers.encode_signed(-1)
      EVM.max_int() - 1
  """
  @spec encode_signed(integer()) :: EVM.val()
  def encode_signed(n) when n < 0, do: EVM.max_int() - abs(n)
  def encode_signed(n), do: n

  @spec decode_signed(integer() | nil) :: EVM.val() | nil
  def decode_signed(n) when is_nil(n), do: 0

  def decode_signed(n) when is_integer(n) do
    if n <= @max_uint_255 do
      n
    else
      n - @max_256_ceiling
    end
  end

  def decode_signed(n) when is_binary(n) do
    n |> :binary.decode_unsigned() |> decode_signed()
  end

  @spec encode_val(integer() | binary() | list(integer())) :: list(EVM.val()) | EVM.val()
  def encode_val(n) when is_binary(n), do: :binary.decode_unsigned(n)
  def encode_val(n) when is_list(n), do: Enum.map(n, &encode_val/1)

  def encode_val(n) do
    n
    |> wrap_int
    |> encode_signed
  end

  @doc """
  Helper function to print an instruction message.
  """
  def inspect(msg, prefix) do
    Logger.debug(inspect([prefix, ":", msg]))

    msg
  end

  @doc """
  Reads a length of data from a binary, filling in all unknown values as zero.

  ## Examples

      iex> EVM.Helpers.read_zero_padded(<<5, 6, 7>>, 1, 3)
      <<6, 7, 0>>

      iex> EVM.Helpers.read_zero_padded(<<5, 6, 7>>, 0, 2)
      <<5, 6>>

      iex> EVM.Helpers.read_zero_padded(<<5, 6, 7>>, 0, 3)
      <<5, 6, 7>>

      iex> EVM.Helpers.read_zero_padded(<<5, 6, 7>>, 4, 3)
      <<0, 0, 0>>
  """
  @spec read_zero_padded(binary(), integer(), integer()) :: binary()
  def read_zero_padded(data, start_pos, read_length) do
    end_pos = start_pos + read_length
    total_data_length = byte_size(data)

    cond do
      start_pos > total_data_length ->
        total_bits = read_length * 8

        <<0::size(total_bits)>>

      end_pos > total_data_length ->
        data_read_length = total_data_length - start_pos
        padding = (read_length - data_read_length) * 8
        binary_part(data, start_pos, data_read_length) <> <<0::size(padding)>>

      true ->
        binary_part(data, start_pos, read_length)
    end
  end

  @doc """
  Left pad binary with bytes

  ## Examples

      iex> EVM.Helpers.left_pad_bytes(1, 3)
      <<0, 0, 1>>
      iex> EVM.Helpers.left_pad_bytes(<<1>>, 3)
      <<0, 0, 1>>
      iex> EVM.Helpers.left_pad_bytes(<<1, 2, 3>>, 2)
      <<1, 2, 3>>
  """
  @spec left_pad_bytes(binary() | integer(), integer()) :: binary()
  def left_pad_bytes(n, size \\ EVM.word_size())

  def left_pad_bytes(n, size) when is_integer(n),
    do: left_pad_bytes(:binary.encode_unsigned(n), size)

  def left_pad_bytes(n, size) when size < byte_size(n), do: n

  def left_pad_bytes(n, size) do
    padding_size = (size - byte_size(n)) * EVM.byte_size()
    <<0::size(padding_size)>> <> n
  end

  @doc """
  Right pad binary with bytes

  ## Examples

      iex> EVM.Helpers.right_pad_bytes(1, 3)
      <<1, 0, 0>>
      iex> EVM.Helpers.right_pad_bytes(<<1>>, 3)
      <<1, 0, 0>>
      iex> EVM.Helpers.right_pad_bytes(<<1, 2, 3>>, 2)
      <<1, 2, 3>>
  """
  @spec right_pad_bytes(binary() | integer(), integer()) :: binary()
  def right_pad_bytes(n, size \\ EVM.word_size())

  def right_pad_bytes(n, size) when is_integer(n),
    do: right_pad_bytes(:binary.encode_unsigned(n), size)

  def right_pad_bytes(n, size) when size < byte_size(n), do: n

  def right_pad_bytes(n, size) do
    padding_size = (size - byte_size(n)) * EVM.byte_size()
    n <> <<0::size(padding_size)>>
  end

  @doc """
  Take the last n bytes of a binary
  """
  @spec take_n_last_bytes(binary(), integer()) :: binary()
  def take_n_last_bytes(data, n) do
    length = byte_size(data)

    :binary.part(data, length - n, n)
  end

  @doc """
  Defined as Eq.(224) in the Yellow Paper, this is "all but one 64th",
  written as L(x).

  ## Examples

      iex> EVM.Helpers.all_but_one_64th(5)
      5

      iex> EVM.Helpers.all_but_one_64th(1000)
      985
  """
  @spec all_but_one_64th(integer()) :: integer()
  def all_but_one_64th(n) do
    round(n - :math.floor(n / 64))
  end
end
