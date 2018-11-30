defmodule ExWire.DEVp2pTest do
  use ExUnit.Case
  doctest ExWire.DEVp2p
  doctest ExWire.DEVp2p.Session

  import ExWire.DEVp2p

  alias ExWire.Packet
  alias ExWire.Packet.Capability

  describe "handles protocol handshake" do
    test "activates session if Hello is sent and received" do
      our_hello = build_hello()
      peer_hello = build_hello()

      session =
        init_session()
        |> hello_sent(our_hello)
        |> hello_received(peer_hello)

      assert session_active?(session)
    end

    test "does not activate the session if hello is only sent" do
      our_hello = build_hello()

      session =
        init_session()
        |> hello_sent(our_hello)

      refute session_active?(session)
    end

    test "does not activate the session if hello is only received" do
      peer_hello = build_hello()

      session =
        init_session()
        |> hello_received(peer_hello)

      refute session_active?(session)
    end

    test "does not activate session if capabilities to not overlap" do
      our_hello = build_hello()
      peer_hello = build_hello() |> set_older_capability()

      session =
        init_session()
        |> hello_sent(our_hello)
        |> hello_received(peer_hello)

      refute session_active?(session)
    end
  end

  describe "session_compatible?/1" do
    test "returns true if any capabilities overlap" do
      our_hello = build_hello()
      peer_hello = build_hello()

      session =
        init_session()
        |> hello_sent(our_hello)
        |> hello_received(peer_hello)

      assert session_compatible?(session)
    end

    test "returns false if no capabilities overlap" do
      our_hello = build_hello()
      peer_hello = build_hello() |> set_older_capability()

      session =
        init_session()
        |> hello_sent(our_hello)
        |> hello_received(peer_hello)

      refute session_compatible?(session)
    end
  end

  describe "handle_message/2" do
    test "returns error if message is not Hello" do
      ping = %Packet.Protocol.Ping{}
      session = init_session()

      assert {:error, :handshake_incomplete} = handle_message(session, ping)
    end

    test "activates a session when Hello message is compatible" do
      hello = build_hello()

      {:ok, session} =
        init_session()
        |> hello_sent(build_hello())
        |> handle_message(hello)

      assert session_active?(session)
    end
  end

  def set_older_capability(packet) do
    %Packet.Protocol.Hello{packet | caps: [Capability.new({"eth", 61})]}
  end

  def active_session do
    our_hello = build_hello()
    peer_hello = build_hello()

    init_session()
    |> hello_sent(our_hello)
    |> hello_received(peer_hello)
  end
end
