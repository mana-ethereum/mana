defmodule ExDevp2p.Messages.Ping do
  def id, do: 0x01
  defstruct [
    :version,
    :from,
    :to,
    :timestamp,
  ]

  alias ExDevp2p.Encodings.Address

  def decode(data) do
    [version, from, to, timestamp] = ExRLP.decode(data)

    %__MODULE__{
      version: :binary.decode_unsigned(version),
      from: Address.decode(from),
      to: Address.decode(to),
      timestamp: timestamp
    }
  end

  def encode(%{
    version: version,
    from: from,
    to: to,
    timestamp: timestamp
  }), do:
    ExRLP.encode([
      version,
      Address.encode(from),
      Address.encode(to),
      timestamp,
    ])
end
