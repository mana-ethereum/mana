defmodule MerklePatriciaTree.Utils do
  def keccak(data) do
    # sha2 instead of sha3 for now
    :crypto.hash(:sha256, data)
  end
end
