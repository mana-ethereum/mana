defmodule JSONRPC2.Response.Helpers do
  @spec encode_hex(binary() | integer() | nil) :: binary()
  def encode_hex(binary) when is_binary(binary) do
    hex_binary = Base.encode16(binary, case: :lower)

    case hex_binary do
      "" ->
        ""

      els ->
        result = String.replace_leading(els, "0", "")

        result = if result == "", do: "0", else: result

        "0x#{result}"
    end
  end

  def encode_hex(value) when is_integer(value) do
    value
    |> :binary.encode_unsigned()
    |> encode_hex()
  end

  def encode_hex(nil), do: nil

  def encode_hex(_value) do
    raise ArgumentError,
      message: "JSONRPC2.Response.Helpers.encode_hex/1 can only encode binary and integer values"
  end
end
