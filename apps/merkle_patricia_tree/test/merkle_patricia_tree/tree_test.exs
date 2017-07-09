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
end
