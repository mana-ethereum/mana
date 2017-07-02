defmodule MerklePatriciaTree.Tree do
  alias MerklePatriciaTree.{DB, Utils}

  def new(key, value) do
    update(:new, key, value)
  end

  def update(node_cap, [], value) do
    node_cap
    |> find_node
    |> update_key(16, value)
    |> save_node
  end

  def update(node_cap, [key | tail], value) do
    current_node = node_cap |> find_node

    updated_node_cap =
      current_node
      |> Enum.at(key)
      |> update(tail, value)

    current_node
    |> update_key(key, updated_node_cap)
    |> save_node
  end

  def delete(node_cap, []) do
    node_cap
    |> find_node
    |> delete_key(16)
    |> save_node
  end

  def delete(node_cap, [key | tail]) do
    current_node = node_cap |> find_node

    updated_node_cap =
      current_node
      |> Enum.at(key)
      |> delete(tail)

    current_node
    |> update_key(key, updated_node_cap)
    |> save_node
  end

  defp update_key(node, key, value) do
    node |> List.replace_at(key, value)
  end

  defp delete_key(node, key) do
    node |> List.delete_at(key)
  end

  defp find_node(node) do
    db_node = DB.get(node)

    if is_nil(db_node), do: new_node(), else: db_node
  end

  defp save_node(node) do
    node_cap = node |> node_cap_function

    DB.put(node_cap, node)

    node_cap
  end

  defp new_node do
    0..16 |> Enum.map(fn(_) -> "" end)
  end

  defp node_cap_function(node) do
    rlp_encoding = node |> ExRLP.encode

    if byte_size(rlp_encoding) > 32,
      do: Utils.keccak(rlp_encoding),
      else: rlp_encoding
  end
end
