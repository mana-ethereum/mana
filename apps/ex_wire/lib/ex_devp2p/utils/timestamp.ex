defmodule ExDevp2p.Utils.Timestamp do
  def now do
    round(:os.system_time(:millisecond) / 1000)
  end
end
