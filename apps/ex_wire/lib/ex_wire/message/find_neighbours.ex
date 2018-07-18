defmodule ExWire.Message.FindNeighbours do
  @moduledoc """
  A wrapper for ExWire's `FindNeighbours` message.

  "Id of a node. The responding node will send back nodes closest to the target."
  """

  @behaviour ExWire.Message
  @message_id 0x03

  alias ExWire.Util.Timestamp

  defstruct target: nil,
            timestamp: nil

  @type t :: %__MODULE__{
          target: ExWire.node_id(),
          timestamp: integer()
        }

  @spec message_id() :: ExWire.Message.message_id()
  def message_id, do: @message_id

  @doc """
  Constructs new FindNeighbours message struct
  """
  def new(node_id) do
    %__MODULE__{
      target: node_id,
      timestamp: Timestamp.soon()
    }
  end

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExWire.Message.FindNeighbours.decode([<<1>>, 2] |> ExRLP.encode)
      %ExWire.Message.FindNeighbours{
        target: <<1>>,
        timestamp: 2,
      }

      iex> ExWire.Message.FindNeighbours.decode([<<1>>] |> ExRLP.encode)
      ** (MatchError) no match of right hand side value: [<<1>>]
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [target, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      target: target,
      timestamp: :binary.decode_unsigned(timestamp)
    }
  end

  @doc """
  Given a FindNeighbours message, encodes it so it can be sent on the wire in RLPx.

  ## Examples

      iex> ExWire.Message.FindNeighbours.encode(%ExWire.Message.FindNeighbours{target: <<1>>, timestamp: 2})
      ...> |> ExRLP.decode()
      [<<1>>, <<2>>]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{target: target, timestamp: timestamp}) do
    ExRLP.encode([
      target,
      timestamp
    ])
  end

  @doc """
  FindNeighbours messages do not specify a destination.

  ## Examples

      iex> ExWire.Message.FindNeighbours.to(%ExWire.Message.FindNeighbours{target: <<1>>, timestamp: 2})
      nil
  """
  @spec to(t) :: ExWire.Struct.Endpoint.t() | nil
  def to(_message), do: nil
end
