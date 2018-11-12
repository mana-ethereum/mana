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
  @spec start(host, :inet.port_number(), atom, Keyword.t(), Keyword.t()) :: :ok
  def start(host, port, name, client_opts \\ [], pool_opts \\ []) do
    host = if is_binary(host), do: to_charlist(host), else: host

    ip =
      case host do
        host when is_list(host) ->
          case :inet.parse_address(host) do
            {:ok, ip} -> ip
            {:error, :einval} -> host
          end

        host ->
          host
      end

    client_opts =
      Keyword.merge([ip: ip, port: port, socket_options: [:binary, packet: :line]], client_opts)

    :shackle_pool.start(name, Protocol, client_opts, pool_opts)
  end

  @doc """
  Stop the client pool with name `name`.
  """
  @spec stop(atom) :: :ok | {:error, :shackle_not_started | :pool_not_started}
  def stop(name) do
    :shackle_pool.stop(name)
  end

  @doc """
  Call the given `method` with `params` using the client pool named `name` with `options`.

  You can provide the option `string_id: true` for compatibility with pathological implementations,
  to force the request ID to be a string.

  You can also provide the option `timeout: 5_000` to set the timeout to 5000ms, for instance.

  For backwards compatibility reasons, you may also provide a boolean for the `options` parameter,
  which will set `string_id` to the given boolean.
  """
  @spec call(atom, JSONRPC2.method(), JSONRPC2.params(), boolean | call_options) ::
          {:ok, {atom(), reference()}}
          | {:error, :backlog_full | :pool_not_started | :shackle_not_started}
  def call(name, method, params, options \\ [])

  def call(name, method, params, string_id) when is_boolean(string_id) do
    call(name, method, params, string_id: string_id)
  end

  def call(name, method, params, options) do
    string_id = Keyword.get(options, :string_id, false)
    timeout = Keyword.get(options, :timeout, @default_timeout)

    :shackle.call(name, {:call, method, params, string_id}, timeout)
  end

  @doc """
  Asynchronously call the given `method` with `params` using the client pool named `name` with
  `options`.

  Use `receive_response/1` with the `request_id` to get the response.

  You can provide the option `string_id: true` for compatibility with pathological implementations,
  to force the request ID to be a string.

  You can also provide the option `timeout: 5_000` to set the timeout to 5000ms, for instance.

  Additionally, you may provide the option `pid: self()` in order to specify which process should
  be sent the message which is returned by `receive_response/1`.

  For backwards compatibility reasons, you may also provide a boolean for the `options` parameter,
  which will set `string_id` to the given boolean.
  """
  @spec cast(atom, JSONRPC2.method(), JSONRPC2.params(), boolean | cast_options) ::
          {:ok, {atom(), reference()}}
          | {:error, :backlog_full | :pool_not_started | :shackle_not_started}
  def cast(name, method, params, options \\ [])

  def cast(name, method, params, string_id) when is_boolean(string_id) do
    cast(name, method, params, string_id: string_id)
  end

  def cast(name, method, params, options) do
    string_id = Keyword.get(options, :string_id, false)
    timeout = Keyword.get(options, :timeout, @default_timeout)
    pid = Keyword.get(options, :pid, self())

    :shackle.cast(name, {:call, method, params, string_id}, pid, timeout)
  end

  @doc """
  Receive the response for a previous `cast/3` which returned a `request_id`.
  """
  @spec receive_response(request_id) :: {:error, any}
  def receive_response(request_id) do
    :shackle.receive_response(request_id)
  end

  @doc """
  Send a notification with the given `method` and `params` using the client pool named `name`.

  This function returns a `request_id`, but it should not be used with `receive_response/1`.
  """
  @spec notify(atom, JSONRPC2.method(), JSONRPC2.params()) ::
          {:ok, {atom(), reference()}}
          | {:error, :backlog_full | :pool_not_started | :shackle_not_started}
  def notify(name, method, params) do
    # Spawn a dead process so responses go to /dev/null
    pid = spawn(fn -> :ok end)
    :shackle.cast(name, {:notify, method, params}, pid, 0)
  end
end
