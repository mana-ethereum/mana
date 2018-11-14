defmodule JSONRPC2.Clients.HTTP do
  @moduledoc """
  A client for JSON-RPC 2.0 using an HTTP transport with JSON in the body.
  """

  @default_headers [{"content-type", "application/json"}]
  alias JSONRPC2.Request
  alias JSONRPC2.Response

  @type batch_result :: {:ok, Response.id_and_response()} | {:error, any}
  @doc """
  Make a call to `url` for JSON-RPC 2.0 `method` with `params`.

  You can also pass `headers`, `http_method`, and `hackney_opts` to customize the options for
  hackney.

  See [hackney](https://github.com/benoitc/hackney) for more information on the available options.
  """
  @spec call(String.t(), JSONRPC2.method(), JSONRPC2.params(), any, atom, list) ::
          {:ok, any} | {:error, any}
  def call(
        url,
        method,
        params,
        headers \\ @default_headers,
        http_method \\ :post,
        hackney_opts \\ []
      ) do
    {:ok, payload} = Request.serialized_request({method, params, 0})
    response = :hackney.request(http_method, url, headers, payload, hackney_opts)

    with(
      {:ok, 200, _headers, body_ref} <- response,
      {:ok, body} <- :hackney.body(body_ref),
      {:ok, {_, result}} <- Response.deserialize_response(body)
    ) do
      result
    else
      {:ok, status_code, headers, body_ref} ->
        {:error, {:http_request_failed, status_code, headers, :hackney.body(body_ref)}}

      {:ok, status_code, headers} ->
        {:error, {:http_request_failed, status_code, headers}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notify via `url` for JSON-RPC 2.0 `method` with `params`.

  You can also pass `headers`, `http_method`, and `hackney_opts` to customize the options for
  hackney.

  See [hackney](https://github.com/benoitc/hackney) for more information on the available options.
  """
  @spec notify(String.t(), JSONRPC2.method(), JSONRPC2.params(), any, atom, list) ::
          :ok | {:error, any}
  def notify(
        url,
        method,
        params,
        headers \\ @default_headers,
        http_method \\ :post,
        hackney_opts \\ []
      ) do

    {:ok, payload} = Request.serialized_request({method, params})

    case :hackney.request(http_method, url, headers, payload, hackney_opts) do
      {:ok, 200, _headers, _body_ref} -> :ok
      {:ok, 200, _headers} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Make a batch request via `url` for JSON-RPC 2.0 `requests`.

  You can also pass `headers`, `http_method`, and `hackney_opts` to customize the options for
  hackney.

  See [hackney](https://github.com/benoitc/hackney) for more information on the available options.
  """
  @spec batch(String.t(), [Request.request()], any, atom, list) ::
          [batch_result] | :ok | {:error, any}
  def batch(url, requests, headers \\ @default_headers, http_method \\ :post, hackney_opts \\ []) do
    {:ok, payload} = Jason.encode(Enum.map(requests, &Request.request/1))

    response = :hackney.request(http_method, url, headers, payload, hackney_opts)

    with(
      {:ok, 200, _headers, body_ref} <- response,
      {:ok, body} <- :hackney.body(body_ref),
      {:ok, deserialized_body} <- Jason.decode(body)
    ) do
      process_batch(deserialized_body)
    else
      {:ok, status_code, headers, body_ref} ->
        {:error, {:http_request_failed, status_code, headers, :hackney.body(body_ref)}}

      {:ok, 200, _headers} ->
        :ok

      {:ok, status_code, headers} ->
        {:error, {:http_request_failed, status_code, headers}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_batch(responses) when is_list(responses) do
    Enum.map(responses, &Response.id_and_response/1)
  end

  defp process_batch(response) do
    Response.id_and_response(response)
  end
end
