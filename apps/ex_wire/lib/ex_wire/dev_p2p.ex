defmodule ExWire.DEVp2p do
  @moduledoc """
  Functions that deal directly with the DEVp2p Wire Protocol.

  For more information, please see:
  https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol
  """

  alias ExWire.Config
  alias ExWire.DEVp2p.Session
  alias ExWire.Packet.Capability.Mana
  alias ExWire.Packet.Protocol.Hello

  @doc """
  Convenience function to create an `ExWire.DEVp2p.Session` struct
  """
  @spec init_session :: Session.t()
  def init_session do
    %Session{}
  end

  @doc """
  Function to create a DEVp2p struct needed for a protocol handshake. This
  should be an `ExWire.Packet.Protocol.Hello` struct with the appropriate values filled in.

  ## Examples

  iex> ExWire.DEVp2p.build_hello().client_id
  "mana/0.0.1"
  """
  @spec build_hello() :: Hello.t()
  def build_hello() do
    %Hello{
      p2p_version: Config.p2p_version(),
      client_id: Config.client_id(),
      caps: Mana.get_our_capabilities(),
      listen_port: Config.listen_port(),
      node_id: Config.node_id()
    }
  end

  @doc """
  Function to update `ExWire.DEVp2p.Session` when a handshake is sent. The
  handshake should be an `ExWire.Packet.Protocol.Hello` that we have sent to a peer.
  """
  @spec hello_sent(Session.t(), Hello.t()) :: Session.t()
  def hello_sent(session, hello = %Hello{}) do
    %{session | hello_sent: hello}
  end

  '''
  Function to update `ExWire.DEVp2p.Session` when a handshake is received. The
  handshake should be an `ExWire.Packet.Protocol.Hello` that we have received from a peer.
  '''

  @spec hello_received(Session.t(), Hello.t()) :: Session.t()
  def hello_received(session, hello = %Hello{}) do
    Session.hello_received(session, hello)
  end

  @doc """
  Function to check whether or not a `ExWire.DEVp2p.Session` is active. See
  `ExWire.DEVp2p.Session.active?/1` for more information.
  """
  @spec session_active?(Session.t()) :: boolean()
  def session_active?(session), do: Session.active?(session)

  @doc """
  Function to check whether or not a `ExWire.DEVp2p.Session` is compatible.
  See `ExWire.DEVp2p.Session.compatible_capabilities?/1` for more information.
  """
  @spec session_compatible?(Session.t()) :: boolean()
  def session_compatible?(session), do: Session.compatible_capabilities?(session)

  @doc """
  Function to handles other messages related to the DEVp2p protocol that a peer
  sends. The messages could be `ExWire.Packet.Protocol.Disconnect`, `ExWire.Packet.Protocol.Ping`,
  or `ExWire.Packet.Protocol.Pong`.

  An `ExWire.DEVp2p.Session` is required as the first argument in order to
  properly update the session based on the message received.
  """
  @spec handle_message(Session.t(), struct()) ::
          {:error, :handshake_incomplete} | {:ok, Session.t()}
  def handle_message(session, packet = %Hello{}) do
    {:ok, hello_received(session, packet)}
  end

  def handle_message(_session, _message) do
    {:error, :handshake_incomplete}
  end
end
