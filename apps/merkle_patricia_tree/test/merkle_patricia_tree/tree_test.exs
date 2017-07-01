defmodule MerklePatriciaTree.TreeTest do
  use ExUnit.Case
  alias MerklePatriciaTree.{Tree, DB}

  setup do
    DB.new

    :ok
  end

  test 'creates root node' do
    key = "dog"
    value = "cat"

    root = Tree.new(key, value)
    db_record = DB.get(root)

    {^key, ^value} = db_record
  end
end
