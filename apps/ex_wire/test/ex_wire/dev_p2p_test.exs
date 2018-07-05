defmodule ExWire.DEVp2pTest do
  use ExUnit.Case
  doctest ExWire.DEVp2p
  doctest ExWire.DEVp2p.Session

  import ExWire.DEVp2p

  alias ExWire.Packet

  describe "handles protocol handshake" do
    test "activates session if hanshake is sent and received" do
      our_hello = generate_handshake()
      peer_hello = generate_handshake()

      session =
        init_session()
        |> handshake_sent(our_hello)
        |> handshake_received(peer_hello)

      assert session_active?(session)
    end

    test "does not activate the session if handshake is only sent" do
      our_hello = generate_handshake()

      session =
        init_session()
        |> handshake_sent(our_hello)

      refute session_active?(session)
    end

    test "does not activate the session if handshake is only received" do
      peer_hello = generate_handshake()

      session =
        init_session()
        |> handshake_received(peer_hello)

      refute session_active?(session)
    end

    test "does not activate session if capabilities to not overlap" do
      our_hello = generate_handshake()
      peer_hello = generate_handshake() |> set_older_capability()

      session =
        init_session()
        |> handshake_sent(our_hello)
        |> handshake_received(peer_hello)

      refute session_active?(session)
    end
  end

  describe "session_compatible?/1" do
    test "returns true if any capabilities overlap" do
      our_hello = generate_handshake()
      peer_hello = generate_handshake()

      session =
        init_session()
        |> handshake_sent(our_hello)
        |> handshake_received(peer_hello)

      assert session_compatible?(session)
    end

    test "returns false if no capabilities overlap" do
      our_hello = generate_handshake()
      peer_hello = generate_handshake() |> set_older_capability()

      session =
        init_session()
        |> handshake_sent(our_hello)
        |> handshake_received(peer_hello)

      refute session_compatible?(session)
    end
  end

  describe "handle_message/2" do
    test "ping messages returns a pong" do
      ping = %Packet.Ping{}

      {:ok, instructions, _session} =
        init_session()
        |> handle_message(ping)

      assert {:send, %Packet.Pong{}} = instructions
    end

    test "disconnects message deactivates session" do
      disconnect = %Packet.Disconnect{}

      {:ok, instructions, session} =
        active_session()
        |> handle_message(disconnect)

      assert instructions == :peer_disconnect
      refute session_active?(session)
    end

    test "hello message updates session" do
      hello = generate_handshake()

      {:ok, instructions, new_session} =
        init_session()
        |> handle_message(hello)

      assert instructions == :activate
      assert new_session.handshake_received == hello
    end
  end

  def set_older_capability(packet) do
    %Packet.Hello{packet | caps: [{"eth", 61}]}
  end

  def active_session do
    our_hello = generate_handshake()
    peer_hello = generate_handshake()

    init_session()
    |> handshake_sent(our_hello)
    |> handshake_received(peer_hello)
  end
end
