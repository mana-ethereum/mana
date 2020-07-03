defmodule ExWire.Rank.PeerDetails do
  @moduledoc """
  A data structure that will help us establish a peers value.
  """
  alias ExWire.Struct.Peer

  @type t :: %__MODULE__{
          peer: Peer.t() | nil,
          connection_duration: Time.t() | nil,
          sent_message_count: non_neg_integer(),
          received_message_count: non_neg_integer()
        }
  defstruct peer: nil,
            connection_duration: nil,
            sent_message_count: 0,
            received_message_count: 0
end
