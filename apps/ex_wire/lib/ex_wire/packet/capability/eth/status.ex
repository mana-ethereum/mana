defmodule ExWire.Packet.Capability.Eth.Status do
  @moduledoc """
  Status messages establish a proper Eth Wire connection, and verify the two clients are compatible.

  ```
  **Status** [`+0x00`: `P`, `protocolVersion`: `P`, `networkId`: `P`, `td`: `P`, `bestHash`: `B_32`, `genesisHash`: `B_32`]

  Inform a peer of its current ethereum state. This message should be sent after the initial
  handshake and prior to any ethereum related messages.

  * `protocolVersion` is one of:
    * `0x00` for PoC-1;
    * `0x01` for PoC-2;
    * `0x07` for PoC-3;
    * `0x09` for PoC-4.
    * `0x17` for PoC-5.
    * `0x1c` for PoC-6.
    * `61` for PV61
    * `62` for PV62
    * `63` for PV63
  * `networkId`: 0=Olympic (disused), 1=Frontier (mainnet), 2=Morden (disused), 3=Ropsten (testnet), 4=Rinkeby
  * `td`: Total Difficulty of the best chain. Integer, as found in block header.
  * `bestHash`: The hash of the best (i.e. highest TD) known block.
  * `genesisHash`: The hash of the Genesis block.
  ```
  """
  alias Blockchain.Chain
  alias ExWire.Bridge.Sync
  require Logger

  @behaviour ExWire.Packet

  @sync Application.get_env(:ex_wire, :sync_mock, Sync)
  @network_id_to_chain_name %{
    0 => :olympic,
    1 => :foundation,
    2 => :morden,
    3 => :ropsten,
    4 => :rinkeby
  }

  @type t :: %__MODULE__{
          protocol_version: integer(),
          network_id: integer(),
          total_difficulty: integer(),
          best_hash: binary(),
          genesis_hash: binary(),
          manifest_hash: binary() | nil,
          block_number: integer() | nil
        }

  defstruct [
    :protocol_version,
    :network_id,
    :total_difficulty,
    :best_hash,
    :genesis_hash,
    :manifest_hash,
    :block_number
  ]

  @doc """
  Create a Status packet to return

  Note: we are currently reflecting values based on the packet received, but
  that should not be the case. We should provide the total difficulty of the
  best chain found in the block header, the best hash, and the genesis hash of
  our blockchain.
  """
  @spec new(integer, binary, binary) :: t()
  def new(total_difficulty, genesis_hash, best_hash) do
    %__MODULE__{
      protocol_version: ExWire.Config.protocol_version(),
      network_id: ExWire.Config.network_id(),
      total_difficulty: total_difficulty,
      best_hash: best_hash,
      genesis_hash: genesis_hash
    }
  end

  @doc """
  Returns the relative message id offset for this message.
  This will help determine what its message ID is relative to other Packets in the same Capability.
  """
  @spec message_id_offset() :: integer()
  def message_id_offset do
    0x00
  end

  @doc """
  Given a Status packet, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Packet.Capability.Eth.Status{protocol_version: 0x63, network_id: 3, total_difficulty: 10, best_hash: <<5>>, genesis_hash: <<4>>}
      ...> |> ExWire.Packet.Capability.Eth.Status.serialize
      [0x63, 3, 10, <<5>>, <<4>>]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(packet = %__MODULE__{}) do
    [
      packet.protocol_version,
      packet.network_id,
      packet.total_difficulty,
      packet.best_hash,
      packet.genesis_hash
    ]
  end

  @doc """
  Given an RLP-encoded Status packet from Eth Wire Protocol, decodes into a Status packet.

  Note: we will decode warp's `manifest_hash` and `block_number`, if given.

  ## Examples

      iex> ExWire.Packet.Capability.Eth.Status.deserialize([<<0x63>>, <<3>>, <<10>>, <<5>>, <<4>>])
      %ExWire.Packet.Capability.Eth.Status{protocol_version: 0x63, network_id: 3, total_difficulty: 10, best_hash: <<5>>, genesis_hash: <<4>>}

      iex> ExWire.Packet.Capability.Eth.Status.deserialize([<<0x63>>, <<3>>, <<10>>, <<5>>, <<4>>, <<11>>, <<11>>])
      %ExWire.Packet.Capability.Eth.Status{protocol_version: 0x63, network_id: 3, total_difficulty: 10, best_hash: <<5>>, genesis_hash: <<4>>, manifest_hash: <<11>>, block_number: 11}
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [protocol_version | rlp_tail] = rlp
    [network_id | rlp_tail] = rlp_tail
    [total_difficulty | rlp_tail] = rlp_tail
    [best_hash | rlp_tail] = rlp_tail
    [genesis_hash | rest] = rlp_tail

    {manifest_hash, block_number} =
      case rest do
        [] ->
          {nil, nil}

        [manifest_hash, block_number] ->
          {manifest_hash, block_number |> :binary.decode_unsigned()}
      end

    %__MODULE__{
      protocol_version: protocol_version |> :binary.decode_unsigned(),
      network_id: network_id |> :binary.decode_unsigned(),
      total_difficulty: total_difficulty |> :binary.decode_unsigned(),
      best_hash: best_hash,
      genesis_hash: genesis_hash,
      manifest_hash: manifest_hash,
      block_number: block_number
    }
  end

  @doc """
  Handles a Status message.

  We should decide whether or not we want to continue communicating with
  this peer. E.g. do our network and protocol versions match?
  """
  @spec handle(ExWire.Packet.packet()) :: ExWire.Packet.handle_response()
  def handle(packet = %__MODULE__{}) do
    if packet.protocol_version == ExWire.Config.protocol_version() do
      Exth.trace(fn -> "[Packet] Got Status: #{inspect(packet)}" end)

      {total_difficulty, genesis_hash, block_hash} =
        case @sync.get_best_block_and_chain() do
          {:ok, block, chain} ->
            {block.header.difficulty, chain.genesis.parent_hash, block.block_hash}

          {:error, error} ->
            _ = Logger.debug(fn -> "Error calling Sync.get_best_block_hash #{error}" end)
            get_default_difficulty_genesis_hash_and_best_hash(packet)
        end

      {:send, new(total_difficulty, genesis_hash, block_hash)}
    else
      # TODO: We need to follow up on disconnection packets with disconnection ourselves
      _ =
        Logger.debug(fn ->
          "[Packet] Disconnecting to due incompatible protocol version (them #{
            packet.protocol_version
          }, us: #{ExWire.Config.protocol_version()})"
        end)

      {:disconnect, :useless_peer}
    end
  end

  defp get_default_difficulty_genesis_hash_and_best_hash(packet) do
    chain = Chain.load_chain(@network_id_to_chain_name[packet.network_id])
    {0, chain.genesis.parent_hash, chain.genesis.parent_hash}
  rescue
    _ ->
      {packet.total_difficulty, packet.genesis_hash, packet.genesis_hash}
  end
end
