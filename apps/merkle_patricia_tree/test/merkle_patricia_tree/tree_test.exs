defmodule MerklePatriciaTree.TreeTest do
  use ExUnit.Case
  alias MerklePatriciaTree.{Tree, DB, HexPrefix}

  setup do
    DB.new

    :ok
  end

  # test 'creates new tree' do
  #   key = "dog" |> HexPrefix.to_nibbles 
  #   value = "cat"

  #   root = Tree.new(key, value)

  #   assert get(root, key) == value
  # end

  def get(node_cap, [key | tail]) do
    node = node_cap |> DB.get(node_cap)

    if is_nil(node) do
      nil
    else
      next_node_cap = node |> Enum.at(key)
      if is_nil(next_node_cap) do
        nil
      else
        get(next_node_cap, tail)
      end
    end
  end
end
