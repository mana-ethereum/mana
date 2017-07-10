defmodule MerklePatriciaTree.Tree do
  defstruct [:db, :root]
  alias MerklePatriciaTree.{Tree, Nibbles, Utils, DB}

  def new(db, root \\ "") do
    root = root |> decode_to_node

    %Tree{db: db, root: root}
  end

  def update(%Tree{db: db, root: root}, key, value) do
    new_root =
      root
      |> update_and_delete_storage(key, value, db)
      |> encode_node(db)

    %Tree{db: db, root: new_root}
  end

  defp update_and_delete_storage(node, key, value, db) do
    type = node |> node_type

    update_node(node, type, key, value, db)
  end

  defp update_node(_node, :blank, key, value, _db) do
    binary_key =
      key
      |> Nibbles.from_binary
      |> Nibbles.add_terminator
      |> Nibbles.hex_prefix_encode

    [binary_key, value]
  end

  defp update_node(node, :branch, "", value, _db) do
    node |> List.update_at(17, value)
  end

  defp update_node(node, :branch, [node_key | key_tail], value, db) do
    new_node_hash =
      node
      |> Enum.at(node_key)
      |> decode_to_node
      |> update_and_delete_storage(key_tail, value, db)
      |> encode_node(db)

    node |> List.replace_at(node_key, new_node_hash)
  end

  defp update_node([node_key, node_value], :leaf, key, value, db) do
    current_key =
      node_key
      |> Nibbles.hex_prefix_decode
      |> Nibbles.remove_terminator

    common_prefix_length = Nibbles.common_prefix_length(current_key, key)

    remaining_key = key |> Enum.drop(common_prefix_length)
    current_remaining_key = current_key |> Enum.drop(common_prefix_length)

    new_node = update_leaf_node(node_value, current_remaining_key, remaining_key, value, db)
  end

  defp update_leaf_node(node_value, [], [], value, db) do
    node_value
    |> decode_to_node
    |> update_and_delete_storage([], value, db)
  end

  defp update_leaf_node(node_value, [], [remaining_key | remaining_tail], value, db) do
    new_node =
      new_branch_node()
      |> List.replace_at(17, node_value)

    remaining_tail_hash =
      remaining_tail
      |> Nibbles.add_terminator
      |> Nibbles.hex_prefix_encode
      |> encode_node(db)

    new_node |> List.replace_at(remaining_key, value)
  end

  defp update_leaf_node(node_value, [cur_key | cur_tail], remaining_key, value, db) do


  end

  defp update_node(node, :extension, key, value) do
  end

  defp decode_to_node("") do
    ""
  end

  defp new_branch_node do
    0..16 |> Enum.map(fn(_) -> "" end)
  end

  defp decode_to_node(hash) when byte_size(hash) <= 32 do
    hash
    |> DB.get
    |> ExRLP.decode
  end

  defp encode_node(root, db) do
    rlp_encoding = root |> ExRLP.encode
    sha3_encoding = rlp_encoding |> Utils.keccak

    DB.put(sha3_encoding, rlp_encoding)

    sha3_encoding
  end

  defp node_type("") do
    :blank
  end

  defp node_type([key, _]) do
    last_nibble =
      key
      |> Nibbles.from_binary
      |> List.last

    node_type(last_nibble)
  end

  defp node_type(16) do
    :leaf
  end

  defp node_type(num) when is_integer(num) do
    :extension
  end

  defp node_type(list) when length(list) == 17 do
    :branch
  end
end
