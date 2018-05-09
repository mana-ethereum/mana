defmodule MerklePatriciaTree.TrieTest do
  use ExUnit.Case, async: true
  doctest MerklePatriciaTree.Trie

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.Verifier

  @max_32_bits 4_294_967_296

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()

    {:ok, %{db: db}}
  end

  def leaf_node(key_end, value) do
    [MerklePatriciaTree.HexPrefix.encode({key_end, true}), value]
  end

  def store(node_value, db) do
    node_hash = :keccakf1600.sha3_256(node_value)
    MerklePatriciaTree.DB.put!(db, node_hash, node_value)

    node_hash
  end

  def extension_node(shared_nibbles, node_hash) do
    [MerklePatriciaTree.HexPrefix.encode({shared_nibbles, false}), node_hash]
  end

  def branch_node(branches, value) when length(branches) == 16 do
    branches ++ [value]
  end

  def blanks(n) do
    for _ <- 1..n, do: []
  end

  def random_key() do
    <<
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32,
      :rand.uniform(@max_32_bits)::32
    >>
  end

  def random_value() do
    <<:rand.uniform(@max_32_bits)::32>>
  end

  test "create trie" do
    trie = Trie.new(MerklePatriciaTree.Test.random_ets_db())

    assert Trie.get(trie, <<0x01, 0x02, 0x03>>) == nil
  end

  describe "get" do
    test "for a simple trie with just a leaf", %{db: db} do
      trie = Trie.new(db)
      trie = %{trie | root_hash: leaf_node([0x01, 0x02, 0x03], "cool")}

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by a leaf", %{db: db} do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node(leaf_node([0x03], "cool"))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "for a trie with an extension node followed by an extension node and then leaf", %{
      db: db
    } do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node(extension_node([0x03], leaf_node([0x04], "cool")))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4, 0x05::4>>) == nil
    end

    test "for a trie with a branch node", %{db: db} do
      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01]
            |> extension_node(branch_node([leaf_node([0x02], "hi") | blanks(15)], "cool"))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == "cool"
      assert Trie.get(trie, <<0x01::4, 0x00::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x02::4>>) == "hi"
      assert Trie.get(trie, <<0x01::4, 0x00::4, 0x0::43>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x01::4>>) == nil
    end

    test "for a trie with encoded nodes", %{db: db} do
      long_string = Enum.join(for _ <- 1..60, do: "A")

      trie = Trie.new(db)

      trie = %{
        trie
        | root_hash:
            [0x01, 0x02]
            |> extension_node([0x03] |> leaf_node(long_string) |> ExRLP.encode() |> store(db))
            |> ExRLP.encode()
            |> store(db)
      }

      assert Trie.get(trie, <<0x01::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == long_string
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end
  end

  describe "update trie" do
    test "add a leaf to an empty tree", %{db: db} do
      trie = Trie.new(db)

      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cool")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "from blog post", %{db: db} do
      trie = Trie.new(db)

      trie_2 = Trie.update(trie, <<0x01::4, 0x01::4, 0x02::4>>, "hello")

      assert trie_2.root_hash ==
               <<73, 98, 206, 73, 94, 192, 23, 36, 174, 248, 169, 73, 103, 133, 200, 167, 68, 83,
                 86, 207, 246, 91, 200, 242, 14, 115, 208, 252, 28, 74, 245, 130>>
    end

    test "update a leaf value (when stored directly)", %{db: db} do
      trie = Trie.new(db, leaf_node([0x01, 0x02], "first"))
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, "second")

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == "first"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == "second"
    end

    test "update a leaf value (when stored in ets)", %{db: db} do
      long_string = Enum.join(for _ <- 1..60, do: "A")
      long_string_2 = Enum.join(for _ <- 1..60, do: "B")

      trie = Trie.new(db, [0x01, 0x02] |> leaf_node(long_string) |> ExRLP.encode() |> store(db))
      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4>>, long_string_2)

      assert Trie.get(trie, <<0x01::4, 0x02::4>>) == long_string
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == long_string_2
    end

    test "update branch under ext node", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<0x01::4, 0x02::4>>, "wee")
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "cool")

      trie_2 = Trie.update(trie, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get(trie_2, <<0x01::4>>) == nil
      assert Trie.get(trie_2, <<0x01::4, 0x02::4>>) == "wee"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cooler"
      assert Trie.get(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "update multiple keys", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4>>, "a")
        |> Trie.update(<<0x01::4, 0x02::4, 0x03::4, 0x04::4>>, "b")
        |> Trie.update(<<0x01::4, 0x02::4, 0x04::4>>, "c")
        |> Trie.update(<<0x01::size(256)>>, "d")

      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "a"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "b"
      assert Trie.get(trie, <<0x01::4, 0x02::4, 0x04::4>>) == "c"
      assert Trie.get(trie, <<0x01::size(256)>>) == "d"
    end

    test "a set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(<<5::4, 7::4, 10::4, 15::4, 15::4>>, "a")
        |> Trie.update(<<5::4, 11::4, 0::4, 0::4, 14::4>>, "b")
        |> Trie.update(<<5::4, 10::4, 0::4, 0::4, 14::4>>, "c")
        |> Trie.update(<<4::4, 10::4, 0::4, 0::4, 14::4>>, "d")
        |> Trie.update(<<5::4, 10::4, 1::4, 0::4, 14::4>>, "e")

      assert Trie.get(trie, <<5::4, 7::4, 10::4, 15::4, 15::4>>) == "a"
      assert Trie.get(trie, <<5::4, 11::4, 0::4, 0::4, 14::4>>) == "b"
      assert Trie.get(trie, <<5::4, 10::4, 0::4, 0::4, 14::4>>) == "c"
      assert Trie.get(trie, <<4::4, 10::4, 0::4, 0::4, 14::4>>) == "d"
      assert Trie.get(trie, <<5::4, 10::4, 1::4, 0::4, 14::4>>) == "e"
    end

    test "yet another set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "yet another set of updates now in memory", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "acceptence testing", %{db: db} do
      {trie, values} =
        Enum.reduce(1..100, {Trie.new(db), []}, fn _, {trie, dict} ->
          key = random_key()
          value = random_value()

          updated_trie = Trie.update(trie, key, value)

          # Verify each key exists in our trie
          for {k, v} <- dict do
            assert Trie.get(trie, k) == v
          end

          {updated_trie, [{key, value} | dict]}
        end)

      # IO.inspect(values)
      # MerklePatriciaTree.Trie.Inspector.inspect_trie(trie)

      # Next, assert tree is well formed
      assert Verifier.verify_trie(trie, values) == :ok
    end
  end
end
