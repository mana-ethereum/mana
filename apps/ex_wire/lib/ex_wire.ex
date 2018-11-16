defmodule ExWire do
  @moduledoc """
  Main application for ExWire. We will begin listening on a port
  when this application is started.
  """
  use Application

  import Supervisor, only: [child_spec: 2]

  @type node_id :: binary()

  alias ExWire.Config
  alias ExWire.NodeDiscoverySupervisor
  alias ExWire.PeerSupervisor
  alias ExWire.Sync
  alias ExWire.TCPListeningSupervisor
  require Logger

  def start(_type, _args) do
    Supervisor.start_link(
      get_children([]),
      strategy: :one_for_one
    )
  end

  @spec get_children(Keyword.t()) :: list(Supervisor.child_spec())
  defp get_children(_params) do
    chain = ExWire.Config.chain()

    perform_discovery = Config.perform_discovery?()

    sync_children =
      if Config.perform_sync?() do
        # If we're not performing discovery, let's immediately connect
        # to the bootnodes given. Otherwise, we'll connect to discovered nodes.
        start_nodes = if perform_discovery, do: [], else: Config.bootnodes()

        [
          # Peer supervisor maintains a pool of outbound peers
          child_spec({PeerSupervisor, start_nodes}, []),

          # Sync coordinates asking peers for new blocks
          child_spec({Sync, chain}, [])
        ]
      else
        []
      end

    node_discovery =
      if perform_discovery do
        # Discovery tries to find new peers
        [child_spec({NodeDiscoverySupervisor, []}, [])]
      else
        []
      end

    # Listener accepts and hands off new inbound TCP connections
    tcp_listening = [child_spec({TCPListeningSupervisor, :ok}, [])]

    sync_children ++ node_discovery ++ tcp_listening
  end
end
