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

  test 'update leaf node value with existing key' do
    db = DB.new
    tree =
      db
      |> Tree.new
      |> Tree.update("rock", "climb")

    %Tree{root: new_root} = tree |> Tree.update("rock", "roll")

    [_, value_in_db] = DB.get(new_root) |> ExRLP.decode
    assert value_in_db == "roll"
  end

  test 'updates leaf node with intersecting key (1)' do
    db = DB.new
    tree =
      db
      |> Tree.new
      |> Tree.update("rock", "roll")

    %Tree{root: new_root} = tree |> Tree.update("rockabilly", "roll")
    branch_node = DB.get(new_root) |> ExRLP.decode
    assert List.last(branch_node) == "roll"

    [_key, value] = <<22, 183, 223, 194, 236, 202, 241, 229, 68, 124, 116, 80, 6, 21, 37, 184, 200,
      49, 100, 200, 47, 23, 37, 82, 36, 73, 46, 133, 102, 23, 151, 105>> |> DB.get |> ExRLP.decode
    assert value == "roll"
  end

  test 'updates leaf node with intersecting key (2)' do
    db = DB.new
    tree =
      db
      |> Tree.new
      |> Tree.update("rockabilly", "roll")

    %Tree{root: new_root} = tree |> Tree.update("rock", "roll")
    branch_node = DB.get(new_root) |> ExRLP.decode
    assert List.last(branch_node) == "roll"

    [_key, value] = <<22, 183, 223, 194, 236, 202, 241, 229, 68, 124, 116, 80, 6, 21, 37, 184, 200,
      49, 100, 200, 47, 23, 37, 82, 36, 73, 46, 133, 102, 23, 151, 105>> |> DB.get |> ExRLP.decode
    assert value == "roll"
  end
end
