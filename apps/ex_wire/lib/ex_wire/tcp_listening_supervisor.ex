defmodule ExWire.TCPListeningSupervisor do
  @moduledoc """
  Top level supervisor for all incoming TCP communications. When a new
  connection comes in, we accept and hand it off to a new `P2P.Server`
  child.
  """
  use Supervisor

  require Logger
  alias ExWire.Config
  alias ExWire.TCP.InboundConnectionsSupervisor
  alias ExWire.TCP.Listener

  @spec start_link(connection_observer: module()) :: Supervisor.on_start()
  def start_link(param = [connection_observer: _connection_observer]) do
    Supervisor.start_link(__MODULE__, param, name: __MODULE__)
  end

  @impl true
  def init(connection_observer: connection_observer) do
    :ok = Logger.info(fn -> "Public node URL: #{Config.public_node_url()}" end)

    port = ExWire.Config.listen_port()

    children = [
      {InboundConnectionsSupervisor, []},
      {Listener, [port: port, name: Listener, connection_observer: connection_observer]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
