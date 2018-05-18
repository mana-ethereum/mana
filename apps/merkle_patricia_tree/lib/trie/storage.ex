defmodule MerklePatriciaTree.Trie.Storage do
  @moduledoc """
  Module to get and put nodes in a trie by the given
  storage mechanism. Generally, handles the function `n(I, i)`,
  Eq.(178) from the Yellow Paper.
  """

  alias ExthCrypto.Hash.Keccak
  alias MerklePatriciaTree.{DB, Trie}

  # Maximum RLP length in bytes that is stored as is
  @max_rlp_len 32

  @spec max_rlp_len() :: integer()
  def max_rlp_len(), do: @max_rlp_len

  @doc """
  Takes an RLP-encoded node and pushes it to storage,
  as defined by `n(I, i)` Eq.(178) of the Yellow Paper.

  Specifically, Eq.(178) says that the node is encoded as `c(J,i)` in the second
  portion of the definition of `n`. By the definition of `c`, all return values are
  RLP encoded. But, we have found emperically that the `n` does not encode values to
  RLP for smaller nodes.

  ## Examples

      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      iex> MerklePatriciaTree.Trie.Storage.put_node(<<>>, trie)
      <<>>
      iex> MerklePatriciaTree.Trie.Storage.put_node("Hi", trie)
      "Hi"
      iex> MerklePatriciaTree.Trie.Storage.put_node(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"], trie)
      <<141, 163, 93, 242, 120, 27, 128, 97, 138, 56, 116, 101, 165, 201,
             165, 139, 86, 73, 85, 153, 45, 38, 207, 186, 196, 202, 111, 84,
             214, 26, 122, 164>>
  """
  @spec put_node(ExRLP.t(), Trie.t()) :: binary()
  def put_node(rlp, trie) do
    case ExRLP.encode(rlp) do
      # Store large nodes
      encoded when byte_size(encoded) >= @max_rlp_len ->
        store(encoded, trie.db)

      # Otherwise, return node itself
      _ ->
        rlp
    end
  end

  @doc """
  Takes an RLP-encoded node, calculates Keccak-256 hash of it
  and stores it in the DB.

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> empty = ExRLP.encode(<<>>)
      iex> MerklePatriciaTree.Trie.Storage.store(empty, db)
      <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91,
            72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
      iex> foo = ExRLP.encode("foo")
      iex> MerklePatriciaTree.Trie.Storage.store(foo, db)
      <<16, 192, 48, 154, 15, 115, 25, 200, 123, 147, 225, 105, 27, 181, 190, 134,
            187, 98, 142, 233, 8, 135, 5, 171, 122, 243, 200, 18, 154, 150, 123, 137>>
  """
  @spec store(ExRLP.t(), MerklePatriciaTree.DB.db()) :: binary()
  def store(rlp_encoded_node, db) do
    # SHA3
    node_hash = Keccak.kec(rlp_encoded_node)

    # Store in db
    DB.put!(db, node_hash, rlp_encoded_node)

    # Return hash
    node_hash
  end

  def delete(trie = %{root_hash: h})
      when not is_binary(h) or h == <<>>,
      do: trie

  def delete(trie),
    do: DB.delete!(trie.db, trie.root_hash)

  @doc """
  Gets the RLP encoded value of a given trie root. Specifically,
  we invert the function `n(I, i)` Eq.(178) from the Yellow Paper.

  ## Examples

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<>>)
      ...> |> MerklePatriciaTree.Trie.Storage.get_node()
      <<>>

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<130, 72, 105>>)
      ...> |> MerklePatriciaTree.Trie.Storage.get_node()
      "Hi"

      iex> MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<254, 112, 17, 90, 21, 82, 19, 29, 72, 106, 175, 110, 87, 220, 249, 140, 74, 165, 64, 94, 174, 79, 78, 189, 145, 143, 92, 53, 173, 136, 220, 145>>)
      ...> |> MerklePatriciaTree.Trie.Storage.get_node()
      :not_found


      iex> trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db(), <<130, 72, 105>>)
      iex> MerklePatriciaTree.Trie.Storage.put_node(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"], trie)
      <<141, 163, 93, 242, 120, 27, 128, 97, 138, 56, 116, 101, 165, 201,
        165, 139, 86, 73, 85, 153, 45, 38, 207, 186, 196, 202, 111, 84,
        214, 26, 122, 164>>
      iex> MerklePatriciaTree.Trie.Storage.get_node(%{trie| root_hash: <<141, 163, 93, 242, 120, 27, 128, 97, 138, 56, 116, 101, 165, 201, 165, 139, 86, 73, 85, 153, 45, 38, 207, 186, 196, 202, 111, 84, 214, 26, 122, 164>>})
      ["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"]
  """
  @spec get_node(Trie.t()) :: ExRLP.t() | :not_found
  def get_node(trie) do
    case trie.root_hash do
      <<>> ->
        <<>>

      # node was stored directly
      x when not is_binary(x) ->
        x

      # stored in db
      h ->
        case DB.get(trie.db, h) do
          {:ok, v} -> ExRLP.decode(v)
          :not_found -> :not_found
        end
    end
  end
end
