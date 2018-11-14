defmodule JSONRPC2.Clients.TCP do
  @moduledoc """
  A client for JSON-RPC 2.0 using a line-based TCP transport.
  """

  alias JSONRPC2.Clients.TCP.Protocol

  @default_timeout 5_000

  @type host :: binary | :inet.socket_address() | :inet.hostname()

  @type request_id :: any

  @type call_option ::
          {:string_id, boolean}
          | {:timeout, pos_integer}

  @type call_options :: [call_option]

  @type cast_options :: [{:string_id, boolean}]

  @doc """
  Start a client pool named `name`, connected to `host` at `port`.

  You can optionally pass `client_opts`, detailed
  [here](https://github.com/lpgauth/shackle#client_options), as well as `pool_opts`, detailed
  [here](https://github.com/lpgauth/shackle#pool_options).
  """
  @spec start(binary()) :: {:ok, pid}
  def start(path) do
    path = if is_binary(path), do: to_charlist(path), else: path

    GenServer.start_link(Protocol, path)
  end

  @doc """
  Stop the client pool with name `name`.
  """
  @spec stop(pid) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Call the given `method` with `params` using the client pool named `name` with `options`.

  You can provide the option `string_id: true` for compatibility with pathological implementations,
  to force the request ID to be a string.

  You can also provide the option `timeout: 5_000` to set the timeout to 5000ms, for instance.

  For backwards compatibility reasons, you may also provide a boolean for the `options` parameter,
  which will set `string_id` to the given boolean.
  """
  @spec call(pid, JSONRPC2.method(), JSONRPC2.params(), boolean | call_options) ::
          {:ok, {atom(), reference()}}
          | {:error, :backlog_full | :pool_not_started | :shackle_not_started}
  def call(pid, method, params, options \\ [])

  def call(pid, method, params, string_id) when is_boolean(string_id) do
    call(pid, method, params, string_id: string_id)
  end

  def call(pid, method, params, options) do
    string_id = Keyword.get(options, :string_id, false)
    timeout = Keyword.get(options, :timeout, @default_timeout)

    case GenServer.call(pid, {:call, method, params, string_id}, timeout) do
      {:ok, {_, result}} -> result
      {:ok, [{_, result}]} -> result
      other -> other
    end
  end
end
