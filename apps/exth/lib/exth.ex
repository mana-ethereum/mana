defmodule Exth do
  @moduledoc """
  General helper functions for inspection and encoding/decoding values.
  """
  require Logger

  @doc """
  Inspect is just like `IO.inspect`, except it allows the caller to add
  a tag that can be printed, as well as showing binaries to unlimited
  length.

  ## Examples

      iex> {1, 2, 3}
      ...> |> Exth.inspect("some tuple data")
      {1, 2, 3}
  """
  @spec inspect(any(), String.t() | nil) :: any()
  def inspect(variable, prefix \\ nil) do
    args = if prefix, do: [prefix, variable], else: variable

    # credo:disable-for-next-line
    IO.inspect(args, limit: :infinity)

    variable
  end

  @doc """
  Function for logging to debug only when a command-line option is set.
  This can be used for turning on deep debugging (e.g. tracing network stacks).
  """
  @spec trace((() -> String.t())) :: :ok
  def trace(fun) do
    _ = if System.get_env("TRACE"), do: Logger.debug(fun)

    :ok
  end

  @doc """
  Simple function that decodes a binary as an unsigned integer. If the
  argument is actually an unsigned integer already, we return it as is.

  ## Examples

      iex> Exth.maybe_decode_unsigned(<<5>>)
      5

      iex> Exth.maybe_decode_unsigned(5)
      5
  """
  @spec maybe_decode_unsigned(integer() | binary()) :: integer()
  def maybe_decode_unsigned(val) when is_integer(val), do: val

  def maybe_decode_unsigned(val) when is_binary(val) do
    :binary.decode_unsigned(val)
  end

  @doc """
  Encodes an usigned integer as a binary.

  ## Examples

      iex> Exth.maybe_encode_unsigned(<<5>>)
      <<5>>

      iex> Exth.maybe_encode_unsigned(5)
      <<5>>
  """
  @spec maybe_encode_unsigned(non_neg_integer() | binary()) :: binary()
  def maybe_encode_unsigned(val) when is_binary(val), do: val

  def maybe_encode_unsigned(val) when is_integer(val) do
    :binary.encode_unsigned(val)
  end

  @doc """
  Encodes a binary to hex, representing the number as a string
  starting with "0x".

  ## Examples

      iex> Exth.encode_hex(<<9,10,11,12>>)
      "0x090a0b0c"

      iex> Exth.encode_hex(<<>>)
      "0x"
  """
  @spec encode_hex(binary()) :: String.t()
  def encode_hex(bin) do
    "0x#{Base.encode16(bin, case: :lower)}"
  end

  @doc """
  Decodes a binary from a hex string. This function works
  with both binaries that begin with and do not begin with
  "0x".

  ## Examples

      iex> Exth.decode_hex("0x090a0b0c")
      <<9,10,11,12>>

      iex> Exth.decode_hex("090a0b0c")
      <<9,10,11,12>>

      iex> Exth.decode_hex("0x")
      <<>>
  """
  @spec decode_hex(String.t()) :: binary()
  def decode_hex("0x" <> bin), do: decode_hex(bin)
  def decode_hex(bin), do: Base.decode16!(bin, case: :mixed)

  @doc """
  Decodes an integer from a hex string.

  ## Examples

      iex> Exth.decode_unsigned_from_hex("0x01")
      1

      iex> Exth.decode_unsigned_from_hex("9c")
      156

      iex> Exth.decode_unsigned_from_hex("0x0f4240")
      1_000_000
  """
  @spec decode_unsigned_from_hex(String.t()) :: integer()
  def decode_unsigned_from_hex(hex_integer) do
    hex_integer
    |> decode_hex()
    |> maybe_decode_unsigned()
  end

  @doc """
  Encodes an integer to a hex string.

  ## Examples

      iex> Exth.encode_unsigned_hex(1)
      "0x01"

      iex> Exth.encode_unsigned_hex(156)
      "0x9c"

      iex> Exth.encode_unsigned_hex(1_000_000)
      "0x0f4240"
  """
  @spec encode_unsigned_hex(integer()) :: String.t()
  def encode_unsigned_hex(integer) do
    integer
    |> maybe_encode_unsigned()
    |> encode_hex()
  end
end
