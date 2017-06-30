defmodule MerklePatriciaTree.DB do
  @table_name :tree

  def new do
    :ets.new(@table_name, [:named_table])
  end

  def get(key) do
    :ets.lookup(@table_name, key)
  end

  def put(key, value) do
    :ets.insert(@table_name, {key, value})
  end
end
