defmodule MerklePatriciaTree.TreeTest do
  use ExUnit.Case
  alias MerklePatriciaTree.{Tree, DB}

  test 'creates new tree' do
    db = DB.new

    tree = Tree.new(db)

    assert %Tree{db: db, root: ""} == tree
  end

  test 'updates tree with empty root' do
    db = DB.new
    key = "rock"
    value = ExRLP.encode(["hello"])
    tree = %Tree{root: root} = Tree.new(db)

    %Tree{root: new_root} = tree |> Tree.update(key, value)

    assert new_root != root

    [_, value_in_db] = DB.get(new_root) |> ExRLP.decode
    assert value_in_db == value
  end

  test 'initializes tree root with existing node' do
    db = DB.new
    %Tree{root: node_hash} =
      db
      |> Tree.new
      |> Tree.update("rock", "roll")

    %Tree{root: [_key, value]} = Tree.new(db, node_hash)

    assert value == "roll"
  end
end
