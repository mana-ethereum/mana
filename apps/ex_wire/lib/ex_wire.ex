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
  alias MerklePatriciaTree.DB.RocksDB

  def start(_type, args) do
    import Supervisor.Spec

    name = Keyword.get(args, :name, ExWire)

    sync_children =
      if Config.sync() do
        db = RocksDB.init(db_name())

        [
          supervisor(PeerSupervisor, [:ok]),
          worker(Sync, [db])
        ]
      else
        []
      end

    node_discovery =
      if Config.discovery() do
        [worker(NodeDiscoverySupervisor, [])]
      else
        []
      end

    tcp_listening = [TCPListeningSupervisor]

    children = sync_children ++ node_discovery ++ tcp_listening

    opts = [strategy: :one_for_one, name: name]
    Supervisor.start_link(children, opts)
  end

  defp db_name() do
    environment = Config.get_environment()
    env = environment |> to_charlist()
    'db/mana-' ++ env
  end
end
