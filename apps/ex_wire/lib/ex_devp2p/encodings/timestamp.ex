defmodule ExDevp2p.Encodings.Timestamp do
  def encode(timestamp) do
    timestamp
  end

  def now do
    round(:os.system_time(:millisecond) / 1000)
  end
end
