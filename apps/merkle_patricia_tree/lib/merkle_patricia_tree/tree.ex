defmodule MerklePatriciaTree.Tree do
  defstruct [:db, :root]
  alias MerklePatriciaTree.{Tree, Nibbles, Utils, DB}

  def new(db, root \\ "") do
    root = root |> decode_to_node

    %Tree{db: db, root: root}
  end

  def get(%Tree{db: db, root: root}, key) do
    node = root |> decode_to_node
    nibble_key = key |> Nibbles.from_binary

    get_node_value(node, nibble_key)
  end

  defp get_node_value(node, key) do
    type = node |> node_type

    get_node_value(node, type, key)
  end

  defp get_node_value(_node, :blank, _key) do
    ""
  end

  defp get_node_value(node, :branch, []) do
    node |> Enum.at(17)
  end

  defp get_node_value(node, :branch, [key | key_tail]) do
    node
    |> Enum.at(key)
    |> decode_to_node
    |> get_node_value(key_tail)
  end

  defp get_node_value([node_key, node_value], :leaf, key) do
    cur_key =
      node_key
      |> Nibbles.hex_prefix_decode
      |> Nibbles.remove_terminator

    if cur_key == key, do: node_value, else: ""
  end

  defp get_node_value([node_key, node_value], :extension, key) do
    cur_key =
      node_key
      |> Nibbles.hex_prefix_decode
      |> Nibbles.remove_terminator

    if Nibbles.starts_with?(key, cur_key) do
      node_value
      |> decode_to_node
      |> get_node_value(key -- cur_key)
    else
      ""
    end
  end

  def update(%Tree{db: db, root: root}, key, value) do
    nibble_key = key |> Nibbles.from_binary
    new_root =
      root
      |> decode_to_node
      |> IO.inspect
      |> update_and_delete_storage(nibble_key, value, db)
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
      |> Nibbles.add_terminator
      |> Nibbles.hex_prefix_encode

    [binary_key, value]
  end

  defp update_node(node, :branch, [], value, _db) do
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

  defp update_node(node, :leaf, key, value, db) do
    current_key =
      node
      |> Enum.at(0)
      |> Nibbles.hex_prefix_decode
      |> Nibbles.remove_terminator

    common_prefix_length = Nibbles.common_prefix_length(current_key, key) |> IO.inspect

    remaining_key = key |> Enum.drop(common_prefix_length) |> IO.inspect
    current_remaining_key = current_key |> Enum.drop(common_prefix_length) |> IO.inspect

    new_node = update_leaf_node(
      node,
      current_remaining_key,
      remaining_key,
      value,
      db
    )

    if common_prefix_length == 0 do
      new_node
    else
      encoded_new_node = encode_node(new_node, db)
      new_node_key =
        current_key
        |> Enum.take(common_prefix_length)
        |> Nibbles.hex_prefix_encode

      [new_node_key, encoded_new_node]
    end
  end

  defp update_leaf_node([node_key, _], [], [], value, db) do
    [node_key, value]
  end

  defp update_leaf_node([node_key, node_value], [], [key | key_tail], value, db) do
    new_node =
      new_branch_node()
      |> List.replace_at(16, node_value)

    remaining_tail_hash =
      key_tail
      |> Nibbles.add_terminator
      |> Nibbles.hex_prefix_encode

    new_leaf_node = [remaining_tail_hash, value] |> encode_node(db)

    new_node |> List.replace_at(key, new_leaf_node)
  end

  defp update_leaf_node([node_key, node_value], [cur_key | cur_tail], remaining_key, value, db) do
    new_node = new_branch_node()

    remaining_cur_key_tail =
      cur_tail
      |> Nibbles.add_terminator
      |> Nibbles.hex_prefix_encode
    new_remaining_node = [remaining_cur_key_tail, node_value] |> encode_node(db)
    new_node = new_node |> List.replace_at(cur_key, new_remaining_node)

    if length(remaining_key) == 0  do
      new_node |> List.replace_at(16, value)
    else
      [key | key_tail] = remaining_key

      remaining_key_tail =
        key_tail
        |> Nibbles.add_terminator
        |> Nibbles.hex_prefix_encode
      new_cur_remaining_node =
        [remaining_key_tail, value]
        |> encode_node(db)

      new_node |> List.replace_at(key, new_cur_remaining_node)
    end
  end

  defp update_node(node, :extension, key, value, db) do
    current_key =
      node
      |> Enum.at(0)
      |> Nibbles.hex_prefix_decode
      |> Nibbles.remove_terminator

    common_prefix_length = Nibbles.common_prefix_length(current_key, key)

    remaining_key = key |> Enum.drop(common_prefix_length)
    current_remaining_key = current_key |> Enum.drop(common_prefix_length)

    new_node = update_extension_node(
      node,
      current_remaining_key,
      remaining_key,
      value,
      db
    )

    if common_prefix_length == 0 do
      new_node
    else
      encoded_new_node = encode_node(new_node, db)
      new_node_key =
        current_key
        |> Enum.take(common_prefix_length)
        |> Nibbles.hex_prefix_encode

      [new_node_key, encoded_new_node]
    end
  end

  defp update_extension_node([node_key, node_value], [], remaining_key, value, db) do
    node_value
    |> decode_to_node
    |> update_and_delete_storage(remaining_key, value, db)
  end

  defp update_extension_node([node_key, node_value], cur_remaining_key, remaining_key, value, db) do
    new_node = new_branch_node()
    [key | key_tail] = remaining_key
    [cur_key | cur_key_tail] = cur_remaining_key

    new_node = if length(cur_remaining_key) == 1 do
        new_node |> List.replace_at(cur_key, node_value)
      else
        remaing_cur_key_hash =
          cur_key_tail
          |> Nibbles.hex_prefix_encode
        new_cur_remaining_node = [remaing_cur_key_hash, node_value] |> encode_node(db)

        new_node |> List.replace_at(cur_key, new_cur_remaining_node)
      end

    if length(remaining_key) == 0 do
      new_node |> List.replace_at(16, value)
    else
      remaining_key_hash =
        key_tail
        |> Nibbles.add_terminator
        |> Nibbles.hex_prefix_encode
      new_remaining_node =
        [remaining_key_hash, value] |> encode_node(db)

      new_node |> List.replace_at(key, new_remaining_node)
    end
  end

  defp new_branch_node do
    0..16 |> Enum.map(fn(_) -> "" end)
  end

  def decode_to_node("") do
    ""
  end

  def decode_to_node(hash) when byte_size(hash) <= 32 do
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
      |> Nibbles.hex_prefix_decode
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
