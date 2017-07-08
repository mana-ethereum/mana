defmodule MerklePatriciaTree.SimpleTreeTest do
  use ExUnit.Case
  alias MerklePatriciaTree.{SimpleTree, DB, Nibbles}

  setup do
    DB.new

    :ok
  end

  test 'creates new tree' do
    key = "dog" |> Nibbles.from_binary
    value = "cat"

    root = SimpleTree.new(key, value)

    assert get(root, key) == value
  end

  test 'updates node' do
    key = "dog" |> Nibbles.from_binary
    value = "cat"
    root = SimpleTree.new(key, value)

    new_value = "tiger"
    new_root = SimpleTree.update(root, key, new_value)

    assert get(new_root, key) == new_value
  end

  test 'deletes node' do
    key = "dog" |> Nibbles.from_binary
    value = "cat"
    root = SimpleTree.new(key, value)

    new_root = SimpleTree.delete(root, key)

    assert get(new_root, key) |> is_nil
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
