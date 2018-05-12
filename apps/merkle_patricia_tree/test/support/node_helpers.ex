defmodule Support.NodeHelpers do
  alias MerklePatriciaTree.HexPrefix

  @max_32_bits 4_294_967_296

  def leaf_node(key_end, value) do
    [HexPrefix.encode({key_end, true}), value]
  end

  def extension_node(shared_nibbles, node_hash) do
    [HexPrefix.encode({shared_nibbles, false}), node_hash]
  end

  def branch_node(branches, value) when length(branches) == 16 do
    branches ++ [value]
  end

  def blanks(n) do
    for _ <- 1..n, do: <<>>
  end

  # 256 bytes
  def random_key() do
    <<
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32
    >>
  end

  # 32 bytes
  def random_value() do
    <<:rand.uniform(@max_32_bits)::32>>
  end
end
