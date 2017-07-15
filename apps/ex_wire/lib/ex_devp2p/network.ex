defmodule ExDevp2p.Network do
  alias ExDevp2p.Crypto
  alias ExDevp2p.Handlers.Ping
  alias ExDevp2p.Protocol

  @ping 0x01

  def receive(data, pid) do
    assert_hash(data)
    handle(data, pid)
  end

  def assert_hash(<< hash :: size(256), payload :: bits >>) do
    Crypto.assert_hash(hash, payload)
  end

  def handle(
    <<
      hash :: size(256),
      signature :: size(512),
      recovery_id:: integer-size(8),
      type:: integer-size(8),
      data :: bitstring
      >>, pid) do

      params = %{
        signature: signature,
        recovery_id: recovery_id,
        hash: hash,
        data: data,
        pid: pid
      }

      case type do
        @ping -> Ping.handle(params)
        _ -> IO.puts "Message code: 0x" <> Base.encode16(<<type>>) <> " not implemented"
      end
  end

  def send(message, pid: pid, to: to) do
    GenServer.cast(
      pid,
      {
        :send,
        %{
          to: to,
          data: Protocol.encode(message),
        }
      }
    )
  end
end
