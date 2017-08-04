defmodule ExDevp2p.Handlers.Ping do
  alias ExDevp2p.Network
  alias ExDevp2p.Messages.Pong
  alias ExDevp2p.Messages.Ping
  alias ExDevp2p.Utils.Timestamp

  def handle(%{
    remote_host: _remote_host,
    signature: _signature,
    recovery_id: _recovery_id,
    pid: pid,
    hash: hash,
    data: data
  }) do
    ping = Ping.decode(data)

    %Pong{
      to: ping.from,
      hash: hash,
      timestamp: Timestamp.now
    } |> Network.send(pid: pid, to: ping.from)
  end
end
