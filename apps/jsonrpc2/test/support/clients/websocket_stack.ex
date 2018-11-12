defmodule JSONRPC2.Clients.WebSocketStack do
  use GenServer
  alias JSONRPC2.Clients.WebSocket
  # Callbacks
  def call(pid, method, args) do
    GenServer.call(pid, {:call, method, args})
  end

  def batch(pid, methods) do
    GenServer.call(pid, {:batch, methods})
  end

  def init(state = %{port: port}) do
    {:ok, connection} = WebSocket.start_link("ws://localhost:#{port}/ws")
    {:ok, Map.put(state, :connection, connection)}
  end

  def handle_call(
        {:call, method, args},
        _from,
        state = %{connection: pid, external_request_id: external_request_id}
      ) do
    :ok = WebSocket.call(pid, method, args, external_request_id)

    receive do
      {:websocket_response, {:ok, [{external_request_id, result}]}} ->
        {:reply, result, %{state | external_request_id: external_request_id + 1}}
    end
  end

  def handle_call(
        {:batch, methods},
        _from,
        state = %{connection: pid, external_request_id: external_request_id}
      ) do
    :ok = WebSocket.batch(pid, methods, external_request_id)

    receive do
      {:websocket_response, {:ok, [{external_request_id, result}]}} ->
        {:reply, result, %{state | external_request_id: external_request_id + 1}}

      {:websocket_response, {:ok, results}} ->
        # get the request id from the response and update it

        data = Enum.map(results, fn {_, {index, _}} -> external_request_id + index end)

        new_external_request_id =
          data
          |> tl
          |> hd

        {:reply, results, %{state | external_request_id: new_external_request_id + 1}}
    end
  end
end
