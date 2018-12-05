defmodule ExWire.Packet.Protocol.Hello do
  @moduledoc """
  This packet establishes capabilities and etc between two peer to peer
  clients. This is generally required to be the first signed packet communicated
  after the handshake is complete.

  ```
  **Hello** `0x00` [`p2pVersion`: `P`, `clientId`: `B`, [[`cap1`: `B_3`, `capVersion1`: `P`], [`cap2`: `B_3`, `capVersion2`: `P`], ...], `listenPort`: `P`, `nodeId`: `B_64`]

  First packet sent over the connection, and sent once by both sides. No other messages
  may be sent until a `Hello` is received.

  * `p2pVersion` Specifies the implemented version of the P2P protocol. Now must be 1.
  * `clientId` Specifies the client software identity, as a human-readable string (e.g. "Ethereum(++)/1.0.0").
  * `cap` Specifies a peer capability name as a length-3 ASCII string. Current supported capabilities are eth, shh.
  * `capVersion` Specifies a peer capability version as a positive integer.
  * `listenPort` specifies the port that the client is listening on (on the interface that the present connection traverses). If 0 it indicates the client is not listening.
  * `nodeId` is the Unique Identity of the node and specifies a 512-bit hash that identifies this node.
  ```
  """

  require Logger
  alias ExWire.Packet.Capability
  alias ExWire.Packet.Capability.Mana

  @behaviour ExWire.Packet

  @type t :: %__MODULE__{
          p2p_version: non_neg_integer(),
          client_id: String.t(),
          caps: [Capability.t()],
          listen_port: integer(),
          node_id: ExWire.node_id()
        }

  defstruct [
    :p2p_version,
    :client_id,
    :caps,
    :listen_port,
    :node_id
  ]

  @impl true
  @spec message_id_offset() :: 0
  def message_id_offset() do
    0x00
  end

  @doc """
  Given a Hello packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Protocol.Hello{p2p_version: 10, client_id: "Mana/Test", caps: [ExWire.Packet.Capability.new({"eth", 1}), ExWire.Packet.Capability.new({"par", 2})], listen_port: 5555, node_id: <<5>>}
      ...> |> ExWire.Packet.Protocol.Hello.serialize
      [10, "Mana/Test", [["eth", 1], ["par", 2]], 5555, <<5>>]
  """
  @impl true
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    [
      packet.p2p_version,
      packet.client_id,
      for(%Capability{name: cap, version: ver} <- packet.caps, do: [cap, ver]),
      packet.listen_port,
      packet.node_id
    ]
  end

  @doc """
  Given an RLP-encoded Hello packet from Eth Wire Protocol,
  decodes into a Hello struct.

  ## Examples

      iex> ExWire.Packet.Protocol.Hello.deserialize([<<10>>, "Mana/Test", [["eth", <<1>>], ["par", <<2>>]], <<55>>, <<5>>])
      %ExWire.Packet.Protocol.Hello{p2p_version: 10, client_id: "Mana/Test", caps: [ExWire.Packet.Capability.new({"eth", 1}), ExWire.Packet.Capability.new({"par", 2})], listen_port: 55, node_id: <<5>>}
  """
  @impl true
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      p2p_version,
      client_id,
      caps,
      listen_port,
      node_id
    ] = rlp

    %__MODULE__{
      p2p_version: p2p_version |> :binary.decode_unsigned(),
      client_id: client_id,
      caps: for([cap, ver] <- caps, do: Capability.new({cap, ver |> :binary.decode_unsigned()})),
      listen_port: listen_port |> :binary.decode_unsigned(),
      node_id: node_id
    }
  end

  @doc """
  Handles a Hello message. We can mark a peer as active for communication
  after we receive this message.

  ## Examples

      # Matching caps

      iex> caps = [ExWire.Packet.Capability.new({"eth", 62}), ExWire.Packet.Capability.new({"par", 2})]
      iex> %ExWire.Packet.Protocol.Hello{p2p_version: 10, client_id: "Mana/Test", caps: caps, listen_port: 5555, node_id: <<5>>}
      ...> |> ExWire.Packet.Protocol.Hello.handle()
      {:activate, [ExWire.Packet.Capability.new({"eth", 62}), ExWire.Packet.Capability.new({"par", 2})], 10}

      # No matching caps

      iex> caps = [ExWire.Packet.Capability.new({"eth", 1}), ExWire.Packet.Capability.new({"par", 2})]
      iex> %ExWire.Packet.Protocol.Hello{p2p_version: 10, client_id: "Mana/Test", caps: caps, listen_port: 5555, node_id: <<5>>}
      ...> |> ExWire.Packet.Protocol.Hello.handle()
      {:disconnect, :useless_peer, [ExWire.Packet.Capability.new({"eth", 1}), ExWire.Packet.Capability.new({"par", 2})], 10}

      # When no caps
      iex> %ExWire.Packet.Protocol.Hello{p2p_version: 10, client_id: "Mana/Test", caps: [], listen_port: 5555, node_id: <<5>>}
      ...> |> ExWire.Packet.Protocol.Hello.handle()
      {:disconnect, :useless_peer, [], 10}
  """
  @impl true
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    Exth.trace(fn -> "[Packet] Got Hello: #{inspect(packet)}" end)

    if Capability.get_matching_capabilities(packet.caps, Mana.get_our_capabilities_map()) == [] do
      _ =
        Logger.debug(fn ->
          "[Packet] Disconnecting due to no matching peer caps (#{inspect(packet.caps)})"
        end)

      {:disconnect, :useless_peer, packet.caps, packet.p2p_version}
    else
      # TODO: Add a bunch more checks
      {:activate, packet.caps, packet.p2p_version}
    end
  end
end
