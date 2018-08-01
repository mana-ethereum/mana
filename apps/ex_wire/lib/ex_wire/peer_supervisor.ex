defmodule ExWire.PeerSupervisor do
  @moduledoc """
  The Peer Supervisor is responsible for maintaining a set of peer TCP connections.

  We should ask bootnodes for a set of potential peers via the Discovery Protocol, and then
  we can connect to those nodes. Currently, we just connect to the Bootnodes themselves.
  """

  # TODO: We need to track and see which of these are up. We need to percolate messages on success.

  use Supervisor

  @name __MODULE__

  def start_link(bootnodes) do
    Supervisor.start_link(__MODULE__, bootnodes, name: @name)
  end

  def init(bootnodes) do
    # TODO: Ask for peers, etc.

    children =
      for bootnode <- bootnodes do
        {:ok, peer} = ExWire.Struct.Peer.from_uri(bootnode)

        worker(ExWire.P2P.Server, [:outbound, peer, [{:server, ExWire.Sync}]])
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Sends a packet to all active TCP connections. This is useful when we want to, for instance,
  ask for a `GetBlockBody` from all peers for a given block hash.
  """
  def send_packet(pid, packet) do
    # Send to all of the Supervisor's children...
    # ... not the best.

    for {_id, child, _type, _modules} <- Supervisor.which_children(pid) do
      # Children which are being restarted by not have a child_pid at this time.
      if is_pid(child), do: ExWire.P2P.Server.send_packet(child, packet)
    end
  end
end
