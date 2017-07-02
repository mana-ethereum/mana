defmodule MerklePatriciaTree.TreeTest do
  use ExUnit.Case
  alias MerklePatriciaTree.{Tree, DB, HexPrefix}

  setup do
    DB.new

    :ok
  end

  test 'creates new tree' do
    key = "dog" |> HexPrefix.to_nibbles
    value = "cat"

    root = Tree.new(key, value)

    assert get(root, key) == value
  end

  test 'updates node' do
    key = "dog" |> HexPrefix.to_nibbles
    value = "cat"
    root = Tree.new(key, value)

    new_value = "tiger"
    new_root = Tree.update(root, key, new_value)

    assert get(new_root, key) == new_value
  end

  def get(node_cap, []) do
    node_cap
    |> DB.get
    |> Enum.at(16)
  end

  def get(node_cap, [key | tail]) do
    node = node_cap |> DB.get

    if is_nil(node) do
      nil
    else
      next_node_cap = node |> Enum.at(key)
      get(next_node_cap, tail)
    end
  end
end
