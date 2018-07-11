defmodule ExWire.TCP.InboundConnectionsSupervisor do
  @moduledoc """
  Dynamic supervisor in charge of handling inbound tcp connections.
  """

  use DynamicSupervisor

  @doc """
  Starts a new supervised process to handle an inbound tcp connection.
  """
  def new_connection_handler(socket) do
    DynamicSupervisor.start_child(__MODULE__, {ExWire.P2P.Server, [:inbound, socket]})
  end

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
