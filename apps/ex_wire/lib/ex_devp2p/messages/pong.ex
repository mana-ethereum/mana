defmodule ExDevp2p.Messages.Pong do
  def id, do: 0x02
  defstruct [
    :to,
    :hash,
    :timestamp,
  ]

  alias ExDevp2p.Encodings.Address

  def decode(data) do
    [to, hash, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      to: Address.decode(to),
      hash: hash,
      timestamp: timestamp
    }
  end

  def encode(%__MODULE__{to: to, hash: hash, timestamp: timestamp}), do:
    ExRLP.encode([
      Address.encode(to),
      hash,
      timestamp,
    ])
end
