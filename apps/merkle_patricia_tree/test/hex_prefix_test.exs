defmodule MerklePatriciaTree.HexPrefixTest do
  use ExUnit.Case, async: true
  doctest MerklePatriciaTree.HexPrefix

  test "encode then decode - no terminator" do
    encoded = {[0x01, 0x02], false} |> MerklePatriciaTree.HexPrefix.encode()
    decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
    assert decoded == {[1, 2], false}
  end

  test "encode then decode - terminator" do
    encoded = {[0x01, 0x02], true} |> MerklePatriciaTree.HexPrefix.encode()
    decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
    assert decoded == {[1, 2], true}
  end
end
