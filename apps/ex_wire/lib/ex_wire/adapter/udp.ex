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
  @spec start_link(atom(), {module(), term()}, integer()) :: GenServer.on_start()
  def start_link(name, {module, args}, port) do
    GenServer.start_link(
      __MODULE__,
      %{network: module, network_args: args, port: port},
      name: name
    )
  end

  @doc """
  Initialize by opening up a `gen_udp` server on a given port.
  """
  @impl true
  def init(state = %{port: port}) do
    {:ok, socket} = :gen_udp.open(port, [:binary])

    {:ok, Map.put(state, :socket, socket)}
  end

  @doc """
  Handle info will handle when we have communication from a peer node.

  We'll offload the effort to our `ExWire.Network` and `ExWire.Handler` modules.

  Note: all responses will be asynchronous.
  """
  @impl true
  def handle_info(
        {:udp, _socket, ip, port, data},
        state = %{network: network, network_args: network_args}
      ) do
    Exth.trace(fn ->
      "Got UDP message from #{inspect(ip)}:#{to_string(port)} with #{byte_size(data)} bytes, handling with {#{
        Atom.to_string(network)
      }, #{inspect(network_args)}}"
    end)

    :ok = handle_inbound_message(ip, port, data, network, network_args)
    {:noreply, state}
  end

  @spec handle_inbound_message(:inet.ip_address(), non_neg_integer(), binary(), module(), term()) ::
          :ok
  defp handle_inbound_message(ip, port, data, network, network_args) do
    ip = Tuple.to_list(ip)

    inbound_message = %ExWire.Network.InboundMessage{
      data: data,
      server_pid: self(),
      remote_host: %ExWire.Struct.Endpoint{
        ip: ip,
        udp_port: port
      },
      timestamp: ExWire.Util.Timestamp.soon()
    }

    apply(network, :receive, [inbound_message, network_args])

    :ok
  end

  @doc """
  For cast, we'll respond back to a given peer with a given message package. This represents
  all outbound messages we'll ever send.
  """
  @impl true
  def handle_cast(
        {:send, %{to: %{ip: ip, udp_port: udp_port}, data: data}},
        state = %{socket: socket}
      )
      when not is_nil(udp_port) do
    Exth.trace(fn ->
      "Sending UDP message to #{inspect(ip)}:#{to_string(udp_port)} with #{byte_size(data)} bytes"
    end)

    tuple_ip = List.to_tuple(ip)
    :ok = :gen_udp.send(socket, tuple_ip, udp_port, data)

    {:noreply, state}
  end
end
