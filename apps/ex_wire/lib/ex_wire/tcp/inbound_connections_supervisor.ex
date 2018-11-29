defmodule ExWire.TCP.InboundConnectionsSupervisor do
  @moduledoc """
  Dynamic supervisor in charge of handling inbound tcp connections.

  """

  use DynamicSupervisor
  alias ExWire.P2P.Server

  @doc """
  Starts a new supervised process to handle an inbound tcp connection.
  """
  @spec new_connection_handler(:gen_tcp.socket(), module()) :: DynamicSupervisor.on_start_child()
  def new_connection_handler(socket, connection_observer) do
    DynamicSupervisor.start_child(__MODULE__, {Server, {:inbound, socket, connection_observer}})
  end

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
