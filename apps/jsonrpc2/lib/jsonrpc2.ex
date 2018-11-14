defmodule JSONRPC2 do
  @moduledoc ~S"""
  `JSONRPC2` is an Elixir library for JSON-RPC 2.0.

  It includes request and response utility modules, a transport-agnostic server handler, UNIX domain socket server and client (in tests),
  which are based on [Ranch] and a JSON-in-the-body HTTP(S) and Websockets server and client (in tests),
  based on [Plug](https://github.com/elixir-lang/plug) and [hackney](https://github.com/benoitc/hackney), respectively.

  """
  use Application

  alias JSONRPC2.Servers.TCP
  alias JSONRPC2.Servers.WebSocketHTTP
  alias JSONRPC2.SpecHandler

  @typedoc "A decoded JSON object."
  @type json ::
          nil
          | true
          | false
          | float
          | integer
          | String.t()
          | [json]
          | %{optional(String.t()) => json}
  @typedoc "A JSON-RPC 2.0 method."
  @type method :: String.t()

  @typedoc "A JSON-RPC 2.0 params value."
  @type params :: [json] | %{optional(String.t()) => json}

  @typedoc "A JSON-RPC 2.0 request ID."
  @type id :: String.t() | number

  def start(_type, _args) do
    ipc = Application.get_env(:jsonrpc2, :ipc)
    http = Application.get_env(:jsonrpc2, :http)
    ws = Application.get_env(:jsonrpc2, :ws)

    ipc_child = get_ipc_child(ipc)
    http_ws_child = get_http_ws_child(http, ws)

    children =
      Enum.filter([ipc_child, http_ws_child], fn
        nil -> false
        _ -> true
      end)

    Supervisor.start_link(children,
      strategy: :one_for_one
    )
  end

  @spec get_ipc_child(Keyword.t()) :: Supervisor.child_spec() | nil
  defp get_ipc_child(enabled: true, path: path) do
    dirname = Path.dirname(path)
    :ok = File.mkdir_p(dirname)
    _ = File.rm(path)
    TCP.child_spec(SpecHandler, 0, transport_opts: [{:ifaddr, {:local, path}}])
  end

  defp get_ipc_child(enabled: false, path: _path), do: nil

  @spec get_http_ws_child(Keyword.t(), Keyword.t()) :: Supervisor.child_spec() | nil
  defp get_http_ws_child(
         _http_config = [enabled: true, port: http_port],
         _ws_config = [enabled: true, port: ws_port]
       ) do
    case http_port do
      ^ws_port ->
        WebSocketHTTP.child_spec(:http, :web_ws, SpecHandler, port: http_port)

      _ ->
        raise(ArgumentError, "HTTP port #{http_port} and WS port #{ws_port} don't match")
    end
  end

  defp get_http_ws_child(
         _http_config = [enabled: true, port: port],
         _ws_config = [enabled: false, port: _port]
       ) do
    WebSocketHTTP.child_spec(:http, :web, SpecHandler, port: port)
  end

  defp get_http_ws_child(
         _http_config = [enabled: false, port: _port],
         _ws_config = [enabled: true, port: port]
       ) do
    WebSocketHTTP.child_spec(:http, :ws, SpecHandler, port: port)
  end

  defp get_http_ws_child(
         _http_config = [enabled: false, port: _],
         _ws_config = [enabled: false, port: _]
       ),
       do: nil
end
