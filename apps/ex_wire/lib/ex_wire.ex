defmodule ExWire do
  @moduledoc """
  Main application for ExWire. We will begin listening on a port
  when this application is started.
  """

  @type node_id :: binary()

  use Application

  alias ExWire.Config
  alias ExWire.NodeDiscoverySupervisor
  alias ExWire.PeerSupervisor
  alias ExWire.Sync
  alias ExWire.TCPListeningSupervisor

  def start(_type, args) do
    import Supervisor.Spec

    name = Keyword.get(args, :name, ExWire)
    chain = ExWire.Config.chain()

    sync_children =
      if Config.perform_sync?() do
        [
          # Peer supervisor maintains a pool of outbound peers
          supervisor(PeerSupervisor, [Config.bootnodes()]),

          # Sync coordinates asking peers for new blocks
          worker(Sync, [chain])
        ]
      else
        []
      end

    node_discovery =
      if Config.perform_discovery?() do
        # Discovery tries to find new peers
        [worker(NodeDiscoverySupervisor, [])]
      else
        []
      end

    # Listener accepts and hands off new inbound TCP connections
    tcp_listening = [TCPListeningSupervisor]

    children = sync_children ++ node_discovery ++ tcp_listening

    opts = [strategy: :one_for_one, name: name]
    Supervisor.start_link(children, opts)
  end
end
