defmodule JSONRPC2.Response do
  @moduledoc """
  JSON-RPC 2.0 Response object utilites.
  """

  @type id_and_response ::
          {JSONRPC2.id() | nil,
           {:ok, any} | {:error, code :: integer, message :: String.t(), data :: any}}

  @doc """
  Deserialize the given `response` using `serializer`.
  """
  @spec deserialize_response(String.t()) :: {:ok, id_and_response} | {:error, any}
  def deserialize_response(response) do
    case Jason.decode(response) do
      {:ok, response} -> id_and_response(response)
      {:error, error} -> {:error, error}
      {:error, error, _} -> {:error, error}
    end
  end

  @doc """
  Returns a tuple containing the information contained in `response`.
  """
  @spec id_and_response(map) :: {:ok, id_and_response} | {:error, any}
  def id_and_response(%{"jsonrpc" => "2.0", "id" => id, "result" => result}) do
    {:ok, {id, {:ok, result}}}
  end

  def id_and_response(%{"jsonrpc" => "2.0", "id" => id, "error" => error}) do
    {:ok, {id, {:error, {error["code"], error["message"], error["data"]}}}}
  end

  def id_and_response(response) do
    {:error, {:invalid_response, response}}
  end
end
