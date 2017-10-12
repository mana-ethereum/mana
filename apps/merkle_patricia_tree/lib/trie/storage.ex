defmodule MerklePatriciaTree.Trie.Storage do
  @moduledoc """
  Module to get and put nodes in a trie by the given
  storage mechanism. Generally, handles the function `n(I, i)`,
  Eq.(178) from the Yellow Paper.
  """

  alias MerklePatriciaTree.DB
  alias MerklePatriciaTree.Trie

  @max_rlp_len 32

  @spec max_rlp_len() :: integer()
  def max_rlp_len(), do: @max_rlp_len

  @doc """
  Takes an RLP-encoded node and pushes it to storage,
  as defined by `n(I, i)` Eq.(178) of the Yellow Paper.

  NOTA BENE: we are forced to deviate from the Yellow Paper as nodes which are
  smaller than 32 bytes aren't encoded in RLP, as suggested by the equations.

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
  @spec put_node(ExRLP.t, Trie.t) :: binary()
  def put_node(rlp, trie) do
    case ExRLP.encode(rlp) do
      encoded when byte_size(encoded) >= @max_rlp_len -> store(encoded, trie.db) # store large nodes
      _ -> rlp # otherwise, return node itself
    end
  end

  @doc """
  TODO: Doc and test
  """
  @spec store(ExRLP.t, MerklePatriciaTree.DB.db) :: binary()
  def store(rlp_encoded_node, db) do
    node_hash = :keccakf1600.sha3_256(rlp_encoded_node) # sha3

    DB.put!(db, node_hash, rlp_encoded_node) # store in db

    node_hash # return hash
  end

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
  @spec get_node(Trie.t) :: ExRLP.t
  def get_node(trie) do
    case trie.root_hash do
      <<>> -> <<>>
      x when not is_binary(x) -> x # node was stored directly
      h ->
        case DB.get(trie.db, h) do # stored in db
          {:ok, v} -> ExRLP.decode(v)
          :not_found -> :not_found
        end
    end
  end

end
