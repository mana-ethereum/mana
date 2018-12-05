defmodule JSONRPC2.Response.Helpers do
  @spec encode_hex(binary() | nil) :: binary()
  def encode_hex(binary) when is_binary(binary) do
    Exth.encode_hex(binary)
  end

  def encode_hex(nil), do: nil

  def encode_hex(_value) do
    raise ArgumentError,
      message: "JSONRPC2.Response.Helpers.encode_hex/1 can only encode binary values"
  end
end
