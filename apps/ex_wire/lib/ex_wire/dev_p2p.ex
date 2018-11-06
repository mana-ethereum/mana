defmodule ExWire.DEVp2p do
  @moduledoc """
  Functions that deal directly with the DEVp2p Wire Protocol.

  For more information, please see:
  https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol
  """

  alias ExWire.{Config, Packet}
  alias ExWire.DEVp2p.Session

  @doc """
  Convenience function to create an `ExWire.DEVp2p.Session` struct
  """
  @spec init_session :: Session.t()
  def init_session do
    %Session{}
  end

  @doc """
  Function to create a DEVp2p struct needed for a protocol handshake. This
  should be an `ExWire.Packet.Hello` struct with the appropriate values filled in.
  """
  @spec build_hello() :: Packet.Hello.t()
  def build_hello() do
    %Packet.Hello{
      p2p_version: Config.p2p_version(),
      client_id: Config.client_id(),
      caps: Config.caps(),
      listen_port: Config.listen_port(),
      node_id: Config.node_id()
    }
  end

  @doc """
  Function to update `ExWire.DEVp2p.Session` when a handshake is sent. The
  handshake should be an `ExWire.Packet.Hello` that we have sent to a peer.
  """
  @spec hello_sent(Session.t(), Packet.Hello.t()) :: Session.t()
  def hello_sent(session, hello = %Packet.Hello{}) do
    %{session | hello_sent: hello}
  end

  @doc """
  Function to update `ExWire.DEVp2p.Session` when a handshake is received. The
  handshake should be an `ExWire.Packet.Hello` that we have received from a peer.
  """
  @spec hello_received(Session.t(), Packet.Hello.t()) :: Session.t()
  def hello_received(session, hello = %Packet.Hello{}) do
    %{session | hello_received: hello}
  end

  @doc """
  Function to check whether or not a `ExWire.DEVp2p.Session` is active. See
  `ExWire.DEVp2p.Session.active?/1` for more information.
  """
  @spec session_active?(Session.t()) :: boolean()
  def session_active?(session), do: Session.active?(session)

  @spec session_compatible?(Session.t()) :: boolean()
  def session_compatible?(session), do: Session.compatible_capabilities?(session)

  @doc """
  Function to handles other messages related to the DEVp2p protocol that a peer
  sends. The messages could be `ExWire.Packet.Disconnect`, `ExWire.Packet.Ping`,
  or `ExWire.Packet.Pong`.

  An `ExWire.DEVp2p.Session` is required as the first argument in order to
  properly update the session based on the message received.
  """
  @spec handle_message(Session.t(), struct()) ::
          {:error, :handshake_incomplete} | {:ok, Session.t()}
  def handle_message(session, packet = %Packet.Hello{}) do
    {:ok, hello_received(session, packet)}
  end

  def handle_message(_session, _message) do
    {:error, :handshake_incomplete}
  end
end
