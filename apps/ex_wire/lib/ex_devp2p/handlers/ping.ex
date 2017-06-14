defmodule ExDevp2p.Handlers.Ping do
  alias ExDevp2p.Actions.Pong
  alias ExDevp2p.Encodings.Ping

  def handle(%{
    signature: _signature,
    recovery_id: _recovery_id,
    pid: pid,
    hash: hash,
    data: data
  }) do
    ping = Ping.decode(data)

    Pong.send(
      to: ping[:from],
      hash: hash,
      pid: pid,
    )
  end
end
