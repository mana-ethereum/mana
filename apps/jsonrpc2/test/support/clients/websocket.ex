defmodule JSONRPC2.Clients.WebSocket do
  @moduledoc """
  A client for JSON-RPC 2.0 using an WebSocket transport with JSON in the body.
  """

  use WebSockex
  require Logger
  alias JSONRPC2.Request
  alias JSONRPC2.Response

  @spec call(pid(), JSONRPC2.method(), JSONRPC2.params(), integer()) ::
          :ok
          | {:error,
             %WebSockex.FrameEncodeError{}
             | %WebSockex.ConnError{}
             | %WebSockex.NotConnectedError{}
             | %WebSockex.InvalidFrameError{}}
          | none

  def call(
        pid,
        method,
        params,
        request_counter
      ) do
    {:ok, _external_request_id, message} = handle_request(:call, method, params, request_counter)
    _ = Logger.info("Sending message: #{message}")
    WebSockex.send_frame(pid, {:text, message})
  end

  def batch(
        pid,
        method,
        _request_counter
      ) do
    {:ok, message} = handle_request(:call, method)
    _ = Logger.info("Sending message: #{message}")
    WebSockex.send_frame(pid, {:text, message})
  end

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{external_request_id: 0, parent: self()}, [])
  end

  def handle_connect(_conn, state) do
    _ = Logger.info("Connected!")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state = %{parent: parent}) do
    {:ok, data, ^state} = handle_data(msg, state)
    send(parent, {:websocket_response, {:ok, data}})
    {:ok, state}
  end

  def handle_disconnect(%{reason: {:local, reason}}, state) do
    _ = Logger.info("Local close with reason: #{inspect(reason)}")
    {:ok, state}
  end

  def handle_disconnect(disconnect_map, state) do
    super(disconnect_map, state)
  end

  defp handle_request(:call, methods) when is_list(methods) do
    {:ok, data} = Jason.encode(Enum.map(methods, &Request.request/1))

    {:ok, data}
  end

  defp handle_request(:call, method, params, request_counter) do
    external_request_id_int = external_request_id(request_counter)

    external_request_id = external_request_id_int

    {:ok, data} = Request.serialized_request({method, params, external_request_id}, Jason)

    {:ok, external_request_id, data}
  end

  # match batch response on character [ 91
  defp handle_data(body = <<91::size(8), _::binary>>, state) do
    {:ok, deserialized_body} = Jason.decode(body)
    {:ok, process_batch(deserialized_body), state}
  end

  defp handle_data(data, state) do
    case Response.deserialize_response(data, Jason) do
      {:ok, {nil, result}} ->
        _ =
          Logger.error([
            inspect(__MODULE__),
            " received response with null ID: ",
            inspect(result)
          ])

        {:ok, [], state}

      {:ok, {id, result}} ->
        {:ok, [{id, result}], state}

      {:error, error} ->
        _ =
          Logger.error([
            inspect(__MODULE__),
            " received invalid response, error: ",
            inspect(error)
          ])

        {:ok, [], state}
    end
  end

  defp external_request_id(request_counter) do
    rem(request_counter, 2_147_483_647)
  end

  defp process_batch(responses) when is_list(responses) do
    Enum.map(responses, &Response.id_and_response/1)
  end

  defp process_batch(response) do
    Response.id_and_response(response)
  end
end
