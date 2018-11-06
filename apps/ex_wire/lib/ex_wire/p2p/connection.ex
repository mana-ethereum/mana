defmodule ExWire.P2P.Connection do
  alias ExWire.DEVp2p.Session
  alias ExWire.Framing.Secrets
  alias ExWire.Handshake
  alias ExWire.Struct.Peer
  alias ExWire.TCP

  @type t :: %__MODULE__{
          peer: Peer.t(),
          socket: TCP.socket(),
          handshake: Handshake.t(),
          secrets: Secrets.t() | nil,
          queued_data: binary(),
          session: Session.t(),
          subscribers: [any()],
          sent_message_count: integer()
        }

  defstruct peer: nil,
            socket: nil,
            handshake: nil,
            secrets: nil,
            queued_data: <<>>,
            session: nil,
            subscribers: [],
            sent_message_count: 0
end
