defmodule ExWire.TCP.Listener do
  @moduledoc """
  Module responsible for opening a tcp listen socket to listen for incoming
  connections. Once a connection is accepted, it will hand off control of the
  accepted socket connection to a separate process.
  """

  use GenServer

  alias ExWire.TCP

  @type state :: %{
          listen_socket: TCP.socket()
        }

  def start_link(args) do
    port = Keyword.fetch!(args, :port)
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, port, name: name)
  end

  def init(port) do
    {:ok, listen_socket} = TCP.listen(port)

    :ok = accept_tcp_connection()

    {:ok, %{listen_socket: listen_socket}}
  end

  @doc """
  Accepts a connection, and gives control of the connection to a separate process
  that will henceforth handle that tcp connection.
  """
  @spec handle_cast(atom(), state()) :: {:noreply, state()}
  def handle_cast(:accept_tcp_connection, state = %{listen_socket: listen_socket}) do
    {:ok, socket} = TCP.accept_connection(listen_socket)
    {:ok, pid} = TCP.InboundConnectionsSupervisor.new_connection_handler(socket)

    :ok = hand_over_control_of_socket(socket, pid)
    :ok = accept_tcp_connection()

    {:noreply, state}
  end

  @spec hand_over_control_of_socket(TCP.socket(), pid()) :: :ok | {:error, any()}
  defp hand_over_control_of_socket(socket, pid) do
    with :ok <- TCP.hand_over_control(socket, pid) do
      TCP.accept_messages(socket)
    end
  end

  @spec accept_tcp_connection() :: :ok
  defp accept_tcp_connection() do
    GenServer.cast(self(), :accept_tcp_connection)
  end
end
