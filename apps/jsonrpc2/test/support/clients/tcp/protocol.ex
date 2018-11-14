defmodule JSONRPC2.Clients.TCP.Protocol do
  use GenServer
  require Logger
  alias JSONRPC2.Request
  alias JSONRPC2.Response
  @moduledoc false
  # API
  def handle_call({:call, method, params, string_id}, _from, state) do
    external_request_id_int = external_request_id(state.request_counter)

    external_request_id =
      if string_id do
        Integer.to_string(external_request_id_int)
      else
        external_request_id_int
      end

    {:ok, data} =
      {method, params, external_request_id}
      |> Request.serialized_request()

    new_state = %{state | request_counter: external_request_id_int + 1}

    response =
      state.socket
      |> :gen_tcp.send([data, "\r\n"])
      |> receive_response(state.socket, 55_000)
      |> handle_data

    {:reply, response, new_state}
  end

  # API

  def start_link(path) do
    GenServer.start_link(__MODULE__, path)
  end

  def init(path) do
    opts = [:binary, active: false, reuseaddr: true]
    response = :gen_tcp.connect({:local, path}, 0, opts)

    case response do
      {:ok, socket} -> {:ok, %{request_counter: 0, socket: socket}}
      {:error, reason} -> {:error, reason}
    end
  end

  def receive_response(data, socket, timeout, result \\ <<>>)

  def receive_response({:error, reason}, _socket, _timeout, _result) do
    {:error, reason}
  end

  def receive_response(:ok, socket, timeout, result) do
    with {:ok, response} <- :gen_tcp.recv(socket, 0, timeout) do
      new_result = result <> response

      if String.ends_with?(response, "\n") do
        {:ok, new_result}
      else
        receive_response(:ok, socket, timeout, new_result)
      end
    end
  end

  def receive_response(data, _socket, _timeout, _result) do
    {:error, data}
  end

  defp handle_data({:error, data}) do
    _ =
      Logger.error([
        inspect(__MODULE__),
        " received invalid response, error: ",
        inspect(data)
      ])

    {:ok, []}
  end

  defp handle_data({:ok, data}) do
    case Response.deserialize_response(data) do
      {:ok, {nil, result}} ->
        _ =
          Logger.error([
            inspect(__MODULE__),
            " received response with null ID: ",
            inspect(result)
          ])

        {:ok, []}

      {:ok, {id, result}} ->
        {:ok, [{id, result}]}

      {:error, error} ->
        _ =
          Logger.error([
            inspect(__MODULE__),
            " received invalid response, error: ",
            inspect(error)
          ])

        {:ok, []}
    end
  end

  defp external_request_id(request_counter) do
    rem(request_counter, 2_147_483_647)
  end
end
