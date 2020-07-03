defmodule ExWire.FakeKademlia do
  @moduledoc """
  Kademlia interface mock.
  """
  use GenServer
  # API
  def get_peers() do
    _ = GenServer.call(__MODULE__, :get_peers_call)
    []
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def init(_), do: {:ok, %{}}

  def handle_call(:setup_get_peers_call, {reporter, _ref}, _state) do
    {:reply, :ok, %{setup_get_peers_call: reporter}}
  end

  def handle_call(:get_peers_call, _, %{setup_get_peers_call: reporter}) do
    _ = send(reporter, :get_peers_call)
    {:reply, :ok, %{}}
  end
end
