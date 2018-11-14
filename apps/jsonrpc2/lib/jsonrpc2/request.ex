defmodule JSONRPC2.Request do
  @moduledoc """
  JSON-RPC 2.0 Request object utilites.
  """
  alias Jason.EncodeError
  alias Protocol.UndefinedError

  @type request ::
          {JSONRPC2.method(), JSONRPC2.params()}
          | {JSONRPC2.method(), JSONRPC2.params(), JSONRPC2.id()}

  @doc """
  Returns a serialized `request` using `serializer`.

  """
  @spec serialized_request(request) ::
          {:ok, binary()} | {:error, EncodeError.t() | %UndefinedError{}}
  def serialized_request(request) do
    Jason.encode(request(request))
  end

  @doc """
  Returns a map representing the JSON-RPC2.0 request object for `request`.
  """
  @spec request(request) :: map
  def request(request)

  def request({method, params})
      when is_binary(method) and (is_list(params) or is_map(params)) do
    %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }
  end

  def request({method, params, id})
      when is_number(id) or is_binary(id) do
    {method, params}
    |> request()
    |> Map.put("id", id)
  end
end
