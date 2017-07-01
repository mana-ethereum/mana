defmodule MerklePatriciaTree.DBTest do
  use ExUnit.Case
  alias MerklePatriciaTree.DB

  setup do
    DB.new

    :ok
  end

  test 'inserts data' do
    key = "key"
    value = "value"

    DB.put(key, value)
    result = DB.get(key)

    ^value = result
  end
end
