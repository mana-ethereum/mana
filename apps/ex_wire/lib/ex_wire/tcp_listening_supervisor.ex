defmodule ExWire.TCPListeningSupervisor do
  @moduledoc """
  Top level supervisor for all incoming TCP communications. When a new
  connection comes in, we accept and hand it off to a new `P2P.Server`
  child.
  """
  use Supervisor

  require Logger

  alias ExWire.Config

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.info("Public node URL: #{Config.public_node_url()}")

    port = ExWire.Config.listen_port()

    children = [
      {ExWire.TCP.InboundConnectionsSupervisor, []},
      {ExWire.TCP.Listener, [port: port, name: ExWire.TCP.Listener]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
