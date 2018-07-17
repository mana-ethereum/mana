defmodule ExWire.DEVp2pCommunicationTest do
  use ExUnit.Case, async: true

  alias ExWire.{Config, Handshake}
  alias ExWire.Struct.Peer

  setup do
    private_key = Config.private_key()
    Application.put_env(:ex_wire, :private_key, private_key)

    {:ok, %{private_key: private_key}}
  end

  test "nodes exchange encrypted handshake and DEVp2p protocol handshake", keys do
    port = 30309

    {:ok, _recipient_pid} = start_recipient_process(port)
    {:ok, initiator_pid} = start_initiator_process(port)

    trace_and_wait_for_messages(initiator_pid)

    assert_received_ack_resp(initiator_pid, keys)
    assert_encrypted_handshake_success(initiator_pid)

    assert_send_hello_packet(initiator_pid)
    assert_session_is_active(initiator_pid)
  end

  defp assert_received_ack_resp(pid, %{private_key: private_key}) do
    assert_received {:trace, ^pid, :receive, {:tcp, _socket, ack_data}}

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

  defp assert_send_hello_packet(pid) do
    assert_received {:trace, ^pid, :receive, {_, {:send, packet_data}}}

    assert %{packet: {packet_mod, _packet_type, _packet_data}} = packet_data
    assert packet_mod == ExWire.Packet.Hello
  end

  defp start_initiator_process(port) do
    peer = build_peer_with_recipient_data(port)
    ExWire.Adapter.TCP.start_link(:outbound, peer)
  end

  defp start_recipient_process(port) do
    ExWire.TCP.Listener.start_link(port: port, name: :listener)
  end

  defp trace_and_wait_for_messages(pid) do
    :erlang.trace(pid, true, [:receive])

    Process.sleep(500)
  end

  def build_peer_with_recipient_data(port) do
    node_id = Config.public_key() |> Peer.hex_node_id()
    host = get_host()

    Peer.new(host, port, node_id)
  end

  defp get_host do
    {:ok, hostname} = :inet.gethostname()
    {:ok, {_, _, _, _, _, [host_tuple]}} = :inet.gethostbyname(hostname)
    host_tuple |> :inet.ntoa() |> to_string()
  end
end
