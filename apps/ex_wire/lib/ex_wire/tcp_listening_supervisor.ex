defmodule ExWire.TCPListeningSupervisor do
  @moduledoc """
  Top level supervisor for all incoming TCP communications.
  """
  require Logger
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.debug("Starting TCPListeningSupervisor")
    port = ExWire.Config.listen_port()

    children = [
      {ExWire.TCP.InboundConnectionsSupervisor, []},
      {ExWire.TCP.Listener, [port: port, name: ExWire.TCP.Listener]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
