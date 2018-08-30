defmodule ExWire do
  @moduledoc """
  Main application for ExWire. We will begin listening on a port
  when this application is started.
  """

  @type node_id :: binary()

  use Application
  require Logger

  alias ExWire.Config

  def start(_type, args) do
    import Supervisor.Spec

    name = Keyword.get(args, :name, ExWire)
    Logger.debug("starting ExWire")

    sync_children =
      if Config.sync() do
        db = MerklePatriciaTree.DB.RocksDB.init(db_path())

        [
          worker(ExWire.PeerSupervisor, [ExWire.Config.bootnodes()]),
          worker(ExWire.Sync, [db])
        ]
      else
        []
      end

    node_discovery =
      if Config.discovery() do
        [
          worker(ExWire.NodeDiscoverySupervisor, [])
        ]
      else
        []
      end

    tcp_listening = [
      ExWire.TCPListeningSupervisor
    ]

    children = sync_children ++ node_discovery ++ tcp_listening

    opts = [strategy: :one_for_one, name: name]
    Supervisor.start_link(children, opts)
  end

  defp db_path() do
    Application.get_env(:ex_wire, :db_path)
  end
end
