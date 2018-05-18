defmodule ExWire.Adapter.UDP do
  @moduledoc """
  Starts a UDP server to handle incoming and outgoing
  peer to peer messages according to RLPx.
  """
  use GenServer

  @doc """
  When starting a UDP server, we'll store a network to use for all
  message handling.
  """
  def start_link({network, network_args}, port, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      %{network: network, network_args: network_args, port: port},
      opts
    )
  end

  @doc """
  Initialize by opening up a `gen_udp` server on a given port.
  """
  def init(state = %{port: port}) do
    {:ok, socket} = :gen_udp.open(port, [:binary])

    {:ok, Map.put(state, :socket, socket)}
  end

  @doc """
  Handle info will handle when we have communucation from a peer node.

  We'll offload the effort to our `ExWire.Network` and `ExWire.Handler` modules.

  Note: all responses will be asynchronous.
  """
  def handle_info(
        {:udp, _socket, ip, port, data},
        state = %{network: network, network_args: network_args}
      ) do
    inbound_message = %ExWire.Network.InboundMessage{
      data: data,
      server_pid: self(),
      remote_host: %ExWire.Struct.Endpoint{
        ip: ip,
        udp_port: port
      },
      timestamp: ExWire.Util.Timestamp.soon()
    }

    apply(network, :receive, [inbound_message | network_args])

    {:noreply, state}
  end

  @doc """
  For cast, we'll respond back to a given peer with a given message package. This represents
  all outbound messages we'll ever send.
  """
  def handle_cast(
        {:send, %{to: %{ip: ip, udp_port: udp_port}, data: data}},
        state = %{socket: socket}
      )
      when not is_nil(udp_port) do
    :gen_udp.send(socket, ip |> List.to_tuple(), udp_port, data)

    {:noreply, state}
  end
end
