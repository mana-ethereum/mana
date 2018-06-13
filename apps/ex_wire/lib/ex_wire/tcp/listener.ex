defmodule ExWire.TCP.Listener do
  @moduledoc """
  Module responsible for opening a tcp listen socket to listen for incoming
  connections. Once a connection is accepted, it will hand off control of the
  accepted socket connection to a separate process.
  """

  use GenServer

  alias ExWire.TCP

  def start_link(args) do
    port = Keyword.fetch!(args, :port)
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, port, name: name)
  end

  def init(port) do
    {:ok, listen_socket} = TCP.listen(port)

    accept_tcp_connection()

    {:ok, %{listen_socket: listen_socket}}
  end

  @doc """
  Accepts a connection, and gives control of the connection to a separate process
  that will henceforth handle that tcp connection.
  """
  def handle_cast(:accept_tcp_connection, state = %{listen_socket: listen_socket}) do
    {:ok, socket} = TCP.accept_connection(listen_socket)
    {:ok, pid} = TCP.InboundConnectionsSupervisor.new_connection_handler()

    TCP.hand_over_control(socket, pid)
    TCP.accept_messages(socket)

    accept_tcp_connection()

    {:noreply, state}
  end

  defp accept_tcp_connection do
    GenServer.cast(self(), :accept_tcp_connection)
  end
end
