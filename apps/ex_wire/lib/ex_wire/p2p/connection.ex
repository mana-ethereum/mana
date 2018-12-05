defmodule ExWire.P2P.Connection do
  @moduledoc """
  The P2P.Connection keeps track of the current state of a P2P connection
  between two Ethereum nodes. We track, for instance, whether we've
  successfully completed auth, and if so, the current message authentication
  codes, etc.
  """
  alias ExWire.DEVp2p.Session
  alias ExWire.Framing.Secrets
  alias ExWire.Handshake
  alias ExWire.Struct.Peer
  alias ExWire.TCP

  @type t :: %__MODULE__{
          peer: Peer.t() | nil,
          socket: TCP.socket(),
          handshake: Handshake.t(),
          secrets: Secrets.t() | nil,
          queued_data: binary() | nil,
          session: Session.t() | nil,
          subscribers: [any()],
          sent_message_count: integer(),
          datas: [binary()],
          last_error: any() | nil,
          is_outbound: boolean(),
          connection_initiated_at: Time.t() | nil
        }

  defstruct peer: nil,
            socket: nil,
            handshake: nil,
            secrets: nil,
            queued_data: <<>>,
            session: nil,
            subscribers: [],
            sent_message_count: 0,
            datas: [],
            last_error: nil,
            is_outbound: false,
            connection_initiated_at: nil
end
