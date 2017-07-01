defmodule MerklePatriciaTree.DB do
  @table_name :tree

  def new do
    :ets.new(@table_name, [:named_table])
  end

  def get(key) do
    {_key, value} =
      @table_name
      |> :ets.lookup(key)
      |> Enum.at(0)

    value
  end

  def put(key, value) do
    :ets.insert(@table_name, {key, value})
  end
end
