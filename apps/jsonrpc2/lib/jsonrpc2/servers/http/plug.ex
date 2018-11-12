defmodule JSONRPC2.Servers.HTTP.Plug do
  @moduledoc """
  A plug that responds to POSTed JSON-RPC 2.0 in the request body.

  If you wish to start a standalone server which will respond to JSON-RPC 2.0
  POSTs at any URL, please see `JSONRPC2.Servers.HTTP`.

  If you wish to mount a JSON-RPC 2.0 handler in an existing Plug-based web
  application (such as Phoenix), you can do so by putting this in your router:

      forward "/jsonrpc", JSONRPC2.Servers.HTTP.Plug, YourJSONRPC2HandlerModule

  The above code will mount the handler `YourJSONRPC2HandlerModule` at the path
  "/jsonrpc".

  The `Plug.Parsers` module for JSON is automatically included in the pipeline,
  and will use the same serializer as is defined in the `:serializer` key of the
  `:jsonrpc2` application. You can override the default options (which are used
  in this example) like so:

      forward "/jsonrpc", JSONRPC2.Servers.HTTP.Plug, [
        handler: YourJSONRPC2HandlerModule,
        plug_parsers_opts: [
          parsers: [:json],
          pass: ["*/*"],
          json_decoder: Application.get_env(:jsonrpc2, :serializer)
        ]
      ]
  """

  use Plug.Builder

  def init(opts) when is_list(opts) do
    handler = Keyword.fetch!(opts, :handler)

    unless Code.ensure_loaded?(handler) do
      raise ArgumentError,
        message: "Could not load handler for #{inspect(__MODULE__)}, got: #{inspect(handler)}"
    end

    Keyword.merge(
      [
        plug_parsers_opts: [
          parsers: [:json],
          pass: ["*/*"],
          json_decoder: Jason
        ]
      ],
      opts
    )
    |> Map.new()
  end

  def init(handler) when is_atom(handler) do
    init(handler: handler)
  end

  plug(:wrap_plug_parsers, builder_opts())
  plug(:handle_jsonrpc2, builder_opts())

  @doc false
  def wrap_plug_parsers(conn, %{plug_parsers_opts: plug_parsers_opts}) do
    Plug.Parsers.call(conn, Plug.Parsers.init(plug_parsers_opts))
  end

  @doc false
  def handle_jsonrpc2(conn = %{method: "POST", body_params: body_params}, opts) do
    handle_jsonrpc2(conn, body_params, opts)
  end

  def handle_jsonrpc2(conn, _opts) do
    resp(conn, 404, "")
  end

  defp handle_jsonrpc2(conn, %Plug.Conn.Unfetched{}, opts) do
    {body, conn} = get_body(conn)
    do_handle_jsonrpc2(conn, body, opts)
  end

  defp handle_jsonrpc2(conn, %{"_json" => body_params}, opts),
    do: do_handle_jsonrpc2(conn, body_params, opts)

  defp handle_jsonrpc2(conn, body_params, opts), do: do_handle_jsonrpc2(conn, body_params, opts)

  defp do_handle_jsonrpc2(conn, body_params, %{handler: handler}) do
    resp_body =
      case handler.handle(body_params) do
        {:reply, reply} -> reply
        :noreply -> ""
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> resp(200, resp_body)
  end

  defp get_body(so_far \\ [], conn) do
    case read_body(conn) do
      {:ok, body, conn} ->
        {IO.iodata_to_binary([so_far | body]), conn}

      {:more, partial_body, conn} ->
        get_body([so_far | partial_body], conn)

      {:error, reason} ->
        raise Plug.Parsers.ParseError, exception: Exception.normalize(:error, reason)
    end
  end
end
