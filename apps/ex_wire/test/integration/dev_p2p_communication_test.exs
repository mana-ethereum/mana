defmodule ExWire.DEVp2pCommunicationTest do
  use ExUnit.Case, async: true

  alias ExthCrypto.Key
  alias ExWire.{Config, Handshake}
  alias ExWire.Struct.Peer

  @moduletag network: true

  setup do
    public_key = Config.public_key()
    private_key = Config.private_key()
    host = get_host()

    {:ok, %{public_key: public_key, private_key: private_key, host: host}}
  end

  test "nodes exchange encrypted handshake and DEVp2p protocol handshake",
       %{private_key: private_key, public_key: public_key, host: host} do
    port = 30_309

    {:ok, _recipient_pid} = start_recipient_process(port)
    {:ok, initiator_pid} = start_initiator_process(host, port, public_key)

    trace_and_wait_for_messages(initiator_pid)

    assert_received_ack_resp(initiator_pid, private_key)
    assert_encrypted_handshake_success(initiator_pid)

    assert_session_is_active(initiator_pid)
  end

  defp assert_received_ack_resp(pid, private_key) do
    assert_received({:trace, ^pid, :receive, {:tcp, _socket, ack_data}})

    {:ok, ack_resp, _, _} = Handshake.read_ack_resp(ack_data, private_key)

    assert %ExWire.Handshake.Struct.AckRespV4{} = ack_resp
  end

  defp assert_encrypted_handshake_success(pid) do
    state = :sys.get_state(pid)

    refute is_nil(state.secrets)
  end

  defp assert_session_is_active(pid) do
    state = :sys.get_state(pid)

    assert ExWire.DEVp2p.session_active?(state.session)
  end

  @spec start_recipient_process(integer()) :: GenServer.on_start()
  defp start_recipient_process(port) do
    ExWire.TCP.Listener.start_link(port: port, name: :listener)
  end

  @spec start_initiator_process(String.t(), integer(), Key.public_key()) :: GenServer.on_start()
  defp start_initiator_process(host, port, public_key) do
    peer = build_peer_with_recipient_data(host, port, public_key)

    ExWire.P2P.Server.start_link(:outbound, peer, [])
  end

  defp trace_and_wait_for_messages(pid) do
    :erlang.trace(pid, true, [:receive])

    Process.sleep(500)
  end

  @spec build_peer_with_recipient_data(String.t(), integer(), Key.public_key()) :: Peer.t()
  defp build_peer_with_recipient_data(host, port, public_key) do
    node_id = Peer.hex_node_id(public_key)

    Peer.new(host, port, node_id)
  end

  @spec get_host() :: :inet.socket_address()
  defp get_host do
    {:ok, hostname} = :inet.gethostname()
    {:ok, {_, _, _, _, _, [host_tuple]}} = :inet.gethostbyname(hostname)

    host_tuple
  end
end
