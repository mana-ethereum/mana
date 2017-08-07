defmodule ExDevp2p.Message.Pong do
  @moduledoc """
  A message for Ethereum's Pong response.
  """

  alias ExDevp2p.Encoding.Address

  @message_id 0x02

  defstruct [
    :to,
    :hash,
    :timestamp,
  ]

  @type t :: %__MODULE__{
    to: EVM.address,
    hash: EVM.hash,
    timestamp: integer()
  }

  @spec message_id() :: ExDevp2p.Message.message_id
  def message_id, do: @message_id

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExDevp2p.Messages.Pong.decode([<<1>>, <<2>>, 3] |> ExRLP.encode)
      %ExDevp2p.Messages.Pong{
        to: <<1>>,
        hash: <<2>>,
        timestamp: 3,
      }

      iex> ExDevp2p.Messages.Pong.decode([<<1>>] |> ExRLP.encode)
      ** (ArgumentError) something
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [to, hash, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      to: apply(Address, :decode, to),
      hash: hash,
      timestamp: timestamp
    }
  end

  @doc """
  Given a Pong message, encodes it so it can be sent on the wire
  from RLPx.

  ## Examples

      iex> ExDevp2p.Messages.Pong.encode(%ExDevp2p.Messages.Pong{to: <<1>>, hash: <<2>>, timestamp: 3})
      ...> |> ExRLP.decode()
      [<<1>>, <<2>>, 3]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{to: to, hash: hash, timestamp: timestamp}) do
    ExRLP.encode([
      Address.encode(to) |> Tuple.to_list,
      hash,
      timestamp,
    ])
  end
end
