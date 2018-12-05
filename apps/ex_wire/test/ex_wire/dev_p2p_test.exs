defmodule ExWire.DEVp2pTest do
  use ExUnit.Case
  doctest ExWire.DEVp2p
  doctest ExWire.DEVp2p.Session

  alias ExWire.DEVp2p
  alias ExWire.Packet
  alias ExWire.Packet.Capability

  describe "handles protocol handshake" do
    test "activates session if Hello is sent and received" do
      our_hello = DEVp2p.build_hello()
      peer_hello = DEVp2p.build_hello()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(our_hello)
        |> DEVp2p.handle_message(peer_hello)

      assert DEVp2p.session_active?(session)
    end

    test "does not activate the session if hello is only sent" do
      our_hello = DEVp2p.build_hello()

      session =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(our_hello)

      refute DEVp2p.session_active?(session)
    end

    test "does not activate the session if hello is only received" do
      peer_hello = DEVp2p.build_hello()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.handle_message(peer_hello)

      refute DEVp2p.session_active?(session)
    end

    test "does not activate session if capabilities to not overlap" do
      our_hello = DEVp2p.build_hello()
      peer_hello = DEVp2p.build_hello() |> set_older_capability()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(our_hello)
        |> DEVp2p.handle_message(peer_hello)

      refute DEVp2p.session_active?(session)
    end
  end

  describe "session_compatible?/1" do
    test "returns true if any capabilities overlap" do
      our_hello = DEVp2p.build_hello()
      peer_hello = DEVp2p.build_hello()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(our_hello)
        |> DEVp2p.handle_message(peer_hello)

      assert DEVp2p.session_compatible?(session)
    end

    test "returns false if no capabilities overlap" do
      our_hello = DEVp2p.build_hello()
      peer_hello = DEVp2p.build_hello() |> set_older_capability()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(our_hello)
        |> DEVp2p.handle_message(peer_hello)

      refute DEVp2p.session_compatible?(session)
    end
  end

  describe "handle_message/2" do
    test "returns error if message is not Hello" do
      ping = %Packet.Protocol.Ping{}
      session = DEVp2p.init_session()

      assert {:error, :handshake_incomplete} = DEVp2p.handle_message(session, ping)
    end

    test "activates a session when Hello message is compatible" do
      hello = DEVp2p.build_hello()

      {:ok, session} =
        DEVp2p.init_session()
        |> DEVp2p.hello_sent(DEVp2p.build_hello())
        |> DEVp2p.handle_message(hello)

      assert DEVp2p.session_active?(session)
    end
  end

  def set_older_capability(packet) do
    %Packet.Protocol.Hello{packet | caps: [Capability.new({"eth", 61})]}
  end

  def active_session do
    our_hello = DEVp2p.build_hello()
    peer_hello = DEVp2p.build_hello()

    DEVp2p.init_session()
    |> DEVp2p.hello_sent(our_hello)
    |> DEVp2p.hello_received(peer_hello)
  end
end
