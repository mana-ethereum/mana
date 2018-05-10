defmodule ExWire.Kademlia do
  @moduledoc """
  Handles Kademlia algorithm state.
  """

  alias ExWire.Kademlia.Server
  alias ExWire.Struct.Peer

  @doc """
  Adds new node to routing table.
  """
  def add_node(peer = %Peer{}, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.cast({:add_node, peer})
  end

  @doc """
  Returns current routing table.
  """
  def routing_table(opts \\ []) do
    opts
    |> process_name()
    |> GenServer.call(:routing_table)
  end

  @doc """
  Returns neighbours of specified node.
  """
  def neighbours(node, opts \\ []) do
    opts
    |> process_name()
    |> GenServer.call({:neighbours, node})
  end

  defp process_name(opts) do
    opts[:process_name] || Server.default_process_name()
  end
end
