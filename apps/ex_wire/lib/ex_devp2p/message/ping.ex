defmodule ExDevp2p.Message.Ping do
  @moduledoc """
  A message for Ethereum's Ping message.
  """

  alias ExDevp2p.Encoding.Address

  @behaviour ExDevp2p.Message
  @message_id 0x01

  defstruct [
    :version,
    :from,
    :to,
    :timestamp,
  ]

  @type t :: %__MODULE__{
    version: integer(),
    from: EVM.address,
    to: EVM.address,
    timestamp: integer()
  }

  @spec message_id() :: ExDevp2p.Message.message_id
  def message_id, do: @message_id

  @doc """
  Decodes a given message binary, which is assumed
  to be an RLP encoded list of elements.

  ## Examples

      iex> ExDevp2p.Messages.Ping.decode([1, <<2>>, <<3>>, 4] |> ExRLP.encode)
      %ExDevp2p.Messages.Ping{
        version: 1,
        from: <<2>>,
        to: <<3>>,
        timestamp: 4,
      }

      iex> ExDevp2p.Messages.Ping.decode([<<1>>] |> ExRLP.encode)
      ** (ArgumentError) something
  """
  @spec decode(binary()) :: t
  def decode(data) do
    [version, from, to, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      version: :binary.decode_unsigned(version),
      from: apply(Address, :decode, from),
      to: apply(Address, :decode, to),
      timestamp: timestamp
    }
  end

  @doc """
  Given a Ping message, encodes it so it can be sent on the wire
  from RLPx.

  ## Examples

      iex> ExDevp2p.Messages.Ping.encode(%ExDevp2p.Messages.Ping{version: 1, from: <<2>>, to: <<3>>, timestamp: 4})
      ...> |> ExRLP.decode()
      [1, <<2>>, <<3>>, 4]
  """
  @spec encode(t) :: binary()
  def encode(%__MODULE__{version: version, from: from, to: to, timestamp: timestamp}) do
    ExRLP.encode([
      version,
      Address.encode(from) |> Tuple.to_list,
      Address.encode(to) |> Tuple.to_list,
      timestamp,
    ])
  end

end
