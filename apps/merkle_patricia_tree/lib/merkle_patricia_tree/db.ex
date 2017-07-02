defmodule MerklePatriciaTree.DB do
  @table_name :tree

  def new do
    :ets.new(@table_name, [:named_table])
  end

  def get(key) do
    result = @table_name |> :ets.lookup(key)

    case result do
      [{_key, value}] -> value
      _               -> nil
    end
  end

  def put(key, value) do
    :ets.insert(@table_name, {key, value})
  end
end
