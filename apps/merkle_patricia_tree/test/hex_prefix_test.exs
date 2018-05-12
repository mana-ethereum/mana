defmodule MerklePatriciaTree.HexPrefixTest do
  use ExUnit.Case, async: true
  doctest MerklePatriciaTree.HexPrefix

  describe "encode then decode" do
    test "even nibbles, no terminator" do
      encoded = {[0x01, 0x02], false} |> MerklePatriciaTree.HexPrefix.encode()
      decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
      assert decoded == {[1, 2], false}
    end

    test "odd nibbles, no terminator" do
      encoded = {[0x01, 0x02, 0x03], false} |> MerklePatriciaTree.HexPrefix.encode()
      decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
      assert decoded == {[1, 2, 3], false}
    end

    test "even nibbles, terminator" do
      encoded = {[0x01, 0x02], true} |> MerklePatriciaTree.HexPrefix.encode()
      decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
      assert decoded == {[1, 2], true}
    end

    test "odd nibbles, terminator" do
      encoded = {[0x01, 0x02, 0x03], true} |> MerklePatriciaTree.HexPrefix.encode()
      decoded = encoded |> MerklePatriciaTree.HexPrefix.decode()
      assert decoded == {[1, 2, 3], true}
    end
  end
end
