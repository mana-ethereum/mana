defmodule ExDevp2p.Encodings.Ping do
  alias ExDevp2p.Encodings.Binary
  alias ExDevp2p.Encodings.Address

  def decode([version, from, to, rest]) do
    %{
      verison: Binary.decode(version),
      to: Address.decode(to),
      from: Address.decode(from),
      rest: rest
    }
  end

  def decode(data) do
    data
      |> ExRLP.decode
      |> decode
  end
end
