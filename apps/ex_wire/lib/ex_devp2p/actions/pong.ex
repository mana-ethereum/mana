defmodule ExDevp2p.Actions.Pong do
  @pong 0x02
  alias ExDevp2p.Encodings.Address
  alias ExDevp2p.Network
  alias ExDevp2p.Encodings.Timestamp

  def send(to: to, hash: hash, pid: pid) do
    data = encode(
            to: to,
            hash: hash,
            timestamp: Timestamp.now)

    Network.send(
      data: data,
      to: to,
      pid: pid
    )
  end

  def encode(to: to, hash: hash, timestamp: timestamp) do
    :binary.encode_unsigned(@pong) <>
      ExRLP.encode(
        [Address.encode(to),
         hash,
         timestamp]
      )
  end
end
