defmodule JSONRPC2.Servers.WebSocketHTTP do
  @moduledoc """
  An HTTP server which responds to POSTed JSON-RPC 2.0 in the request body.

  This server will respond to all requests on the given port. If you wish to mount a JSON-RPC 2.0
  handler within a Plug-based web app (such as Phoenix), please see `JSONRPC2.Servers.HTTP.Plug`.
  """

  alias JSONRPC2.Servers.HTTP.Plug, as: JSONRPC2Plug
  alias JSONRPC2.Servers.WebSocket
  alias Plug.Cowboy

  @type configuration :: %__MODULE__{
          type: :ws | :web,
          enabled: boolean(),
          port: pos_integer(),
          interface: :local | :all | :inet.ip_address(),
          max_connections: pos_integer()
        }

  defstruct [:type, :enabled, :port, :interface, :max_connections]

  @spec new(Keyword.t(), :ws | :web) :: configuration()
  def new(
        [enabled: enabled, port: port, interface: interface, max_connections: max_connections],
        type
      ) do
    %__MODULE__{
      type: type,
      enabled: enabled,
      port: port,
      interface: interface,
      max_connections: max_connections
    }
  end

  @doc """
      Four things can happen when it comes to listening to WS and HTTP:
    - If the provided configuration points to the same port and interface we need to spawn *one* cowboy child with both installed dispatchers.
    - If the provided configuration points to the same port and *different* interfaces we need to spawn *two* cowboy children where dispatchers are separated.
    - If the provided configuration points to different ports we need to spawn *two* cowboy children where dispatchers are separated.
    - Both port and interface are different.
    Possible interfaces are
    - All (default)
    - Local (points to 0.0.0.0)
    - IP
    We need to add handler details:
    --ws-apis=[APIS]
    --ws-hosts=[HOSTS]
    --jsonrpc-apis=[APIS]
    --jsonrpc-hosts=[HOSTS]
  """
  @spec children(configuration(), configuration(), module()) ::
          list(Supervisor.child_spec()) | Supervisor.child_spec() | []
  def children(
        http_config,
        ws_config,
        handler_module
      ) do
    get_http_ws_child(http_config, ws_config, handler_module)
  end

  @spec get_http_ws_child(configuration(), configuration(), module()) ::
          list(Supervisor.child_spec())
          | Supervisor.child_spec()
          | []
  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: port, interface: :all},
         _ws_config = %__MODULE__{enabled: true, port: port, interface: :all},
         handler_module
       ) do
    child_spec(:web_ws, handler_module, http_config)
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: port, interface: :local},
         _ws_config = %__MODULE__{enabled: true, port: port, interface: :local},
         handler_module
       ) do
    child_spec(:web_ws, handler_module, http_config)
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: port, interface: ip},
         _ws_config = %__MODULE__{enabled: true, port: port, interface: ip},
         handler_module
       ) do
    child_spec(:web_ws, handler_module, http_config)
  end

  # case 2
  # raise error when one points to local and other binds all interfaces on the same port
  defp get_http_ws_child(
         _http_config = %__MODULE__{enabled: true, port: port, interface: :all},
         _ws_config = %__MODULE__{enabled: true, port: port, interface: :local},
         _handler_module
       ) do
    raise(
      ArgumentError,
      "Can't bind HTTP on all interfaces and WS on {0,0,0,0} (local) interface with the same port."
    )
  end

  defp get_http_ws_child(
         _http_config = %__MODULE__{enabled: true, port: port, interface: :local},
         _ws_config = %__MODULE__{enabled: true, port: port, interface: :all},
         _handler_module
       ) do
    raise(
      ArgumentError,
      "Can't bind WS on all interfaces and HTTP on {0,0,0,0} (local) interface with the same port."
    )
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: port, interface: _http_ip},
         ws_config = %__MODULE__{enabled: true, port: port, interface: _ws_ip},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  # case 3
  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: :all},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: :all},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: :local},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: :local},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: ip},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: ip},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  # case 4
  # different interface that doesn't interfere on different ports
  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: :local},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: :all},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: :all},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: :local},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  # different ports, different interfaces
  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true, port: _http_port, interface: _http_ip},
         ws_config = %__MODULE__{enabled: true, port: _ws_port, interface: _ws_ip},
         handler_module
       ) do
    [
      child_spec(:web, handler_module, http_config),
      child_spec(:ws, handler_module, ws_config)
    ]
  end

  # disabled WS
  defp get_http_ws_child(
         http_config = %__MODULE__{enabled: true},
         _ws_config = %__MODULE__{enabled: false},
         handler_module
       ) do
    child_spec(:web, handler_module, http_config)
  end

  # disabled HTTP
  defp get_http_ws_child(
         _http_config = %__MODULE__{enabled: false},
         ws_config = %__MODULE__{enabled: true},
         handler_module
       ) do
    child_spec(:ws, handler_module, ws_config)
  end

  defp get_http_ws_child(
         _http_config = %__MODULE__{enabled: false},
         _ws_config = %__MODULE__{enabled: false},
         _handler_module
       ),
       do: []

  '''
  Returns a supervisor child spec for the given `handler` via http scheme with `cowboy_opts`.

  Allows you to embed a server directly in your app's supervision tree, rather than letting
  Plug/Cowboy handle it.

  Please see the docs for [Plug](https://hexdocs.pm/plug/Plug.Adapters.Cowboy.html) for the values
  which are allowed in `cowboy_opts`.

  If the server `ref` is not set in `cowboy_opts`, `handler.HTTP` or `handler.HTTPS` is the default.
  '''

  @spec child_spec(:web_ws | :web | :ws, module, configuration) :: Supervisor.child_spec()
  defp child_spec(type, handler, configuration) do
    port = Map.get(configuration, :port)

    ip =
      case Map.get(configuration, :interface) do
        :local -> {0, 0, 0, 0}
        :all -> :any
        ip -> ip
      end

    max_connections = Map.get(configuration, :max_connections)

    cowboy_opts = [
      ip: ip,
      port: port,
      transport_options: [max_connections: max_connections],
      ref: ref(type, JSONRPC2Plug)
    ]

    dispatch = compile_dispatcher(type, handler)
    do_child_spec(handler, Keyword.merge(cowboy_opts, dispatch))
  end

  defp do_child_spec(handler, cowboy_opts) do
    Cowboy.child_spec([
      {:scheme, :http},
      {:plug, {JSONRPC2Plug, [handler: handler]}},
      {:options, cowboy_opts}
    ])
  end

  defp ref(type, handler), do: Module.concat([handler, type, HTTP])

  defp compile_dispatcher(:web_ws, handler) do
    dispatch_web_ws(
      WebSocket,
      {:handler, handler},
      JSONRPC2Plug,
      JSONRPC2Plug.init(handler: handler)
    )
  end

  defp compile_dispatcher(:web, handler) do
    dispatch_http(
      JSONRPC2Plug,
      JSONRPC2Plug.init(handler: handler)
    )
  end

  defp compile_dispatcher(:ws, handler) do
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
