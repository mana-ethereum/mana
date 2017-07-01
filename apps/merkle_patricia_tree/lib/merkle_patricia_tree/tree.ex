defmodule MerklePatriciaTree.Tree do
  alias MerklePatriciaTree.{DB, Utils}

  def new(key, value) do
    node = node_cap_function(key, value)

    DB.put(node, {key, value})

    node
  end

  def update(node, key, value) do

  end

  defp node_cap_function(key, value) do
    binary = key <> value
    rlp_encoding = binary |> ExRLP.encode

    if byte_size(rlp_encoding) > 32,
      do: Utils.keccak(rlp_encoding),
      else: rlp_encoding
  end
end
