defmodule MerklePatriciaTree.UtilsTest do
  use ExUnit.Case
  alias MerklePatriciaTree.Utils

  test 'calculates keccak hash' do
    data = "dog"

    hash = data |> Utils.keccak

    refute hash |> is_nil
  end
end
