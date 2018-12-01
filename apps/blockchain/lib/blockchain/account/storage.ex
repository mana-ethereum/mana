defmodule Blockchain.Account.Storage do
  @moduledoc """
  Represents the account storage,
  as defined in Section 4.1 of the Yellow Paper.

  A mapping between addresses and account states is stored in a modified Merkle
  Patricia tree.  The trie requires a simple database backend
  (the state database) that maintains a mapping of bytearrays to bytearrays.
  """

  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.TrieStorage

  @spec put(TrieStorage.t(), EVM.trie_root(), integer(), integer()) ::
          {TrieStorage.t(), TrieStorage.t()}
  def put(trie_storage, root, key, value) do
    k = encode_key(key)
    v = encode_value(value)

    TrieStorage.update_subtrie_key(trie_storage, root, k, v)
  end

  @spec remove(TrieStorage.t(), EVM.trie_root(), non_neg_integer()) ::
          {TrieStorage.t(), TrieStorage.t()}
  def remove(trie_storage, root, key) do
    k = encode_key(key)

    TrieStorage.remove_subtrie_key(trie_storage, root, k)
  end

  @spec fetch(TrieStorage.t(), EVM.trie_root(), non_neg_integer()) :: any() | nil
  def fetch(trie_storage, root, key) do
    k = encode_key(key)

    result = TrieStorage.get_subtrie_key(trie_storage, root, k)

    if is_nil(result), do: nil, else: ExRLP.decode(result)
  end

  @spec encode_key(integer() | binary()) :: Trie.key()
  def encode_key(key) when is_integer(key) do
    key
    |> BitHelper.encode_unsigned()
    |> encode_key()
  end

  def encode_key(key) when is_binary(key) do
    key
    |> BitHelper.pad(32)
    |> Keccak.kec()
  end

  @spec encode_value(any()) :: binary() | nil
  def encode_value(nil), do: nil
  def encode_value(value), do: ExRLP.encode(value)

  def dump(db, root) do
    db
    |> Trie.new(root)
    |> Trie.Inspector.all_values()
    |> Enum.into(%{}, fn {k, v} ->
      {BitHelper.decode_unsigned(k), BitHelper.decode_unsigned(v)}
    end)
  end
end
