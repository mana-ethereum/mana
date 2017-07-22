defmodule MerklePatriciaTree.Utils do
  def keccak(data) do
    :keccakf1600.sha3_256(data)
  end
end
