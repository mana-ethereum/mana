defmodule ExWire.Packet.Disconnect do
  @moduledoc """
  Disconnect is when a peer wants to end a connection for a reason.

  ```
  **Disconnect** `0x01` [`reason`: `P`]

  Inform the peer that a disconnection is imminent; if received, a peer should
  disconnect immediately. When sending, well-behaved hosts give their peers a
  fighting chance (read: wait 2 seconds) to disconnect to before disconnecting
  themselves.

  * `reason` is an optional integer specifying one of a number of reasons for disconnect:
    * `0x00` Disconnect requested;
    * `0x01` TCP sub-system error;
    * `0x02` Breach of protocol, e.g. a malformed message, bad RLP, incorrect magic number &c.;
    * `0x03` Useless peer;
    * `0x04` Too many peers;
    * `0x05` Already connected;
    * `0x06` Incompatible P2P protocol version;
    * `0x07` Null node identity received - this is automatically invalid;
    * `0x08` Client quitting;
    * `0x09` Unexpected identity (i.e. a different identity to a previous connection/what a trusted peer told us).
    * `0x0a` Identity is the same as this node (i.e. connected to itself);
    * `0x0b` Timeout on receiving a message (i.e. nothing received since sending last ping);
    * `0x10` Some other reason specific to a subprotocol.
  ```
  """

  require Logger

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
    reason: integer()
  }

  defstruct [
    :reason
  ]

  @reason_msgs %{
    disconnect_request: "disconnect requested",
    tcp_sub_system_error: "TCP sub-system error",
    break_of_protocol: "breach of protocol",
    useless_peer: "useless peer",
    too_many_peers: "too many peers",
    already_connected: "already connected",
    incompatible_p2p_protcol_version: "incompatible P2P protocol version",
    null_node_identity_received: "null node identity received",
    client_quitting: "client quitting",
    unexpected_identity: "unexpected identity",
    identity_is_same_as_self: "identity is the same as this node",
    timeout_on_receiving_message: "timeout on receiving a message",
    other_reason: "some other reason specific to a subprotocol"
  }

  @reasons %{
    disconnect_request: 0x00,
    tcp_sub_system_error: 0x01,
    break_of_protocol: 0x02,
    useless_peer: 0x03,
    too_many_peers: 0x04,
    already_connected: 0x05,
    incompatible_p2p_protcol_version: 0x06,
    null_node_identity_received: 0x07,
    client_quitting: 0x08,
    unexpected_identity: 0x09,
    identity_is_same_as_self: 0x0a,
    timeout_on_receiving_message: 0x0b,
    other_reason: 0x10,
  }

  @reasons_inverted (for {k, v} <- @reasons, do: {v, k}) |> Enum.into(%{})

  @doc """
  Given a Disconnect packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Disconnect{reason: timeout_on_receiving_message}
      ...> ExWire.Packet.Disconnect.serialize
      [0x0b]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(packet=%__MODULE__{}) do
    [
      Map.get(@reasons, packet.reason)
    ]
  end

  @doc """
  Given an RLP-encoded Disconnect packet from Eth Wire Protocol,
  decodes into a Disconnect struct.

  ## Examples

      iex> ExWire.Packet.Disconnect.deserialize([0x0b])
      %ExWire.Packet.Disconnect{reason: :timeout_on_receiving_message}
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      reason
    ] = rlp

    %__MODULE__{
      reason: @reasons_inverted[reason |> :binary.decode_unsigned]
    }
  end

  @doc """
  Creates a new disconnect message with given reason. This
  function raises if `reason` is not a known reason.

  ## Examples

      iex> ExWire.Packet.Disconnect.new(:too_many_peers)
      %ExWire.Packet.Disconnect{reason: :too_many_peers}

      iex> ExWire.Packet.Disconnect.new(:something_else)
      ** (ArgumentError) invalid raison
  """
  def new(reason) do
    if @reasons[reason] == nil, do: raise "Invalid reason"

    %__MODULE__{
      reason: reason
    }
  end

  @doc """
  Returns a string interpretation of a reason for disconnect.

  ## Examples

      iex> ExWire.Packet.Disconnect.get_reason_msg(:timeout_on_receiving_message)
      "Timeout on receiving a message"
  """
  @spec get_reason_msg(integer()) :: String.t
  def get_reason_msg(reason) do
    @reason_msgs[reason]
  end

  @doc """
  Handles a Disconnect message. We are instructed to disconnect, which
  we'll abide by.

  ## Examples

      iex> %ExWire.Packet.GetBlockBodies{hashes: [<<5>>, <<6>>]}
      ...> |> ExWire.Packet.GetBlockBodies.handle()
      :ok
  """
  @spec handle(ExWire.Packet.packet) :: ExWire.Packet.handle_response
  def handle(packet=%__MODULE__{}) do
    Logger.info("[Packet] Peer asked to disconnect for #{get_reason_msg(packet.reason) || packet.reason}.")

    :peer_disconnect
  end
end