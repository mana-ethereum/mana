defmodule JSONRPC2.Servers.WebSocketHTTP do
  @moduledoc """
  An HTTP server which responds to POSTed JSON-RPC 2.0 in the request body.

  This server will respond to all requests on the given port. If you wish to mount a JSON-RPC 2.0
  handler within a Plug-based web app (such as Phoenix), please see `JSONRPC2.Servers.HTTP.Plug`.
  """

  alias JSONRPC2.Servers.HTTP.Plug, as: JSONRPC2Plug
  alias JSONRPC2.Servers.WebSocket
  alias Plug.Cowboy

  @doc """
  Returns a supervisor child spec for the given `handler` via `scheme` with `cowboy_opts`.

  Allows you to embed a server directly in your app's supervision tree, rather than letting
  Plug/Cowboy handle it.

  Please see the docs for [Plug](https://hexdocs.pm/plug/Plug.Adapters.Cowboy.html) for the values
  which are allowed in `cowboy_opts`.

  If the server `ref` is not set in `cowboy_opts`, `handler.HTTP` or `handler.HTTPS` is the default.
  """
  @spec child_spec(:http | :https, :web_ws | :web | :ws, module, list) :: Supervisor.child_spec()
  def child_spec(scheme, type, handler, cowboy_opts \\ []) do
    cowboy_opts = Keyword.merge(cowboy_opts, ref: ref(scheme, JSONRPC2Plug))
    dispatch = get_dispatcher(type, handler)
    do_child_spec(scheme, handler, Keyword.merge(cowboy_opts, dispatch))
  end

  defp do_child_spec(scheme, handler, cowboy_opts) do
    Cowboy.child_spec([
      {:scheme, scheme},
      {:plug, {JSONRPC2Plug, [handler: handler]}},
      {:options, cowboy_opts}
    ])
  end

  defp ref(_scheme = :http, handler), do: Module.concat([handler, HTTP])
  defp ref(_scheme = :https, handler), do: Module.concat([handler, HTTPS])

  defp get_dispatcher(:web_ws, handler) do
    dispatch_web_ws(
      WebSocket,
      {:handler, handler},
      JSONRPC2Plug,
      JSONRPC2Plug.init(handler: handler)
    )
  end

  defp get_dispatcher(:web, handler) do
    dispatch_http(
      JSONRPC2Plug,
      JSONRPC2Plug.init(handler: handler)
    )
  end

  defp get_dispatcher(:ws, handler) do
    dispatch_ws(
      WebSocket,
      {:handler, handler}
    )
  end

  defp dispatch_web_ws(socket_handler, socket_definition, plug, plug_definition) do
    [
      dispatch: [
        {:_,
         [
           {"/ws", socket_handler, [socket_definition]},
           {:_, [], Plug.Cowboy.Handler, {plug, plug_definition}}
         ]}
      ]
    ]
  end

  defp dispatch_ws(socket_handler, socket_definition) do
    [
      dispatch: [
        {:_,
         [
           {"/ws", socket_handler, [socket_definition]}
         ]}
      ]
    ]
  end

  defp dispatch_http(plug, plug_definition) do
    [
      dispatch: [
        {:_,
         [
           {:_, [], Plug.Cowboy.Handler, {plug, plug_definition}}
         ]}
      ]
    ]
  end
end
