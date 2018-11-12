defmodule JSONRPC2.Servers.WebSocket do
  @behaviour :cowboy_websocket

  @moduledoc """
  A server for JSON-RPC 2.0 using WebSocket transport.
  """

  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  def websocket_init(opts) when is_list(opts) do
    handler = Keyword.fetch!(opts, :handler)

    unless Code.ensure_loaded?(handler) do
      raise ArgumentError,
        message: "Could not load handler for #{inspect(__MODULE__)}, got: #{inspect(handler)}"
    end

    {:ok, Map.new(opts)}
  end

  def websocket_handle({:text, body_params}, state = %{handler: _handler}) do
    do_handle_jsonrpc2(body_params, state)
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end

  def terminate(_reason, _req, _state) do
    :ok
  end

  defp do_handle_jsonrpc2(body_params, state = %{handler: handler}) do
    resp_body =
      case handler.handle(body_params) do
        {:reply, reply} -> reply
        :noreply -> ""
      end

    {:reply, {:text, resp_body}, state}
  end
end
