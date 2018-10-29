defmodule MerklePatriciaTree.TrieTest do
  use ExUnit.Case, async: true

  doctest MerklePatriciaTree.Trie

  import Support.NodeHelpers, only: :functions
  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.{Storage, Verifier}

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()

    {:ok, %{db: db}}
  end

  test "create trie" do
    trie = Trie.new(MerklePatriciaTree.Test.random_ets_db())

    assert trie.root_hash == Trie.empty_trie_root_hash()
    assert Trie.get_key(trie, <<0x01, 0x02, 0x03>>) == nil
  end

  describe "get" do
    test "with just one leaf", %{db: db} do
      root_hash = leaf_node([0x01, 0x02, 0x03], "cool")
      trie = Trie.new(db, root_hash)

      assert Trie.get_key(trie, <<0x01::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "with an extension node followed by a leaf", %{db: db} do
      root_hash =
        [0x01, 0x02]
        |> extension_node(leaf_node([0x03], "cool"))
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      assert Trie.get_key(trie, <<0x01::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "with an extension node followed by an extension node and then leaf", %{db: db} do
      root_node =
        extension_node(
          [0x01, 0x02],
          extension_node(
            [0x03],
            leaf_node([0x04], "cool")
          )
        )

      root_hash =
        root_node
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      assert Trie.get_key(trie, <<0x01::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "cool"
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4, 0x05::4>>) == nil
    end

    test "with a branch node", %{db: db} do
      root_node =
        extension_node(
          [0x01],
          branch_node(
            [leaf_node([0x02], "hi") | blanks(15)],
            "cool"
          )
        )

      root_hash =
        root_node
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      assert Trie.get_key(trie, <<0x01::4>>) == "cool"
      assert Trie.get_key(trie, <<0x01::4, 0x00::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x00::4, 0x02::4>>) == "hi"
      assert Trie.get_key(trie, <<0x01::4, 0x00::4, 0x0::43>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x01::4>>) == nil
    end

    test "with encoded nodes", %{db: db} do
      long_string = Enum.join(for _ <- 1..60, do: "A")

      root_hash =
        [0x01, 0x02]
        |> extension_node(
          [0x03]
          |> leaf_node(long_string)
          |> ExRLP.encode()
          |> Storage.store(db)
        )
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      assert Trie.get_key(trie, <<0x01::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4>>) == long_string
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end
  end

  describe "update trie" do
    test "add a leaf to an empty tree", %{db: db} do
      trie_1 = Trie.new(db)
      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x02::4, 0x03::4>>, "cool")

      assert Trie.get_key(trie_2, <<0x01::4>>) == nil
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cool"
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "from blog post", %{db: db} do
      trie_1 = Trie.new(db)
      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x01::4, 0x02::4>>, "hello")

      assert trie_2.root_hash ==
               <<73, 98, 206, 73, 94, 192, 23, 36, 174, 248, 169, 73, 103, 133, 200, 167, 68, 83,
                 86, 207, 246, 91, 200, 242, 14, 115, 208, 252, 28, 74, 245, 130>>
    end

    test "update a leaf value (when stored directly)", %{db: db} do
      trie_1 = Trie.new(db, leaf_node([0x01, 0x02], "first"))
      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x02::4>>, "second")

      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4>>) == "second"
    end

    test "update a leaf value (when stored in ets)", %{db: db} do
      long_string_1 = Enum.join(for _ <- 1..60, do: "A")
      long_string_2 = Enum.join(for _ <- 1..60, do: "B")

      root_hash =
        [0x01, 0x02]
        |> leaf_node(long_string_1)
        |> ExRLP.encode()
        |> Storage.store(db)

      trie_1 = Trie.new(db, root_hash)
      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x02::4>>, long_string_2)

      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4>>) == long_string_2
    end

    test "update branch under ext node", %{db: db} do
      trie_1 =
        db
        |> Trie.new()
        |> Trie.update_key(<<0x01::4, 0x02::4>>, "wee")
        |> Trie.update_key(<<0x01::4, 0x02::4, 0x03::4>>, "cool")

      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x02::4, 0x03::4>>, "cooler")

      assert Trie.get_key(trie_2, <<0x01::4>>) == nil
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4>>) == "wee"
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4>>) == "cooler"
      assert Trie.get_key(trie_2, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == nil
    end

    test "update multiple keys", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update_key(<<0x01::4, 0x02::4, 0x03::4>>, "a")
        |> Trie.update_key(<<0x01::4, 0x02::4, 0x03::4, 0x04::4>>, "b")
        |> Trie.update_key(<<0x01::4, 0x02::4, 0x04::4>>, "c")
        |> Trie.update_key(<<0x01::size(256)>>, "d")

      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4>>) == "a"
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x03::4, 0x04::4>>) == "b"
      assert Trie.get_key(trie, <<0x01::4, 0x02::4, 0x04::4>>) == "c"
      assert Trie.get_key(trie, <<0x01::size(256)>>) == "d"
    end

    test "update a leaf deep in ext nodes", %{db: db} do
      key = <<0x01::4, 0x01::4, 0x01::4, 0x02::4, 0x01::4, 0x05::4>>

      trie_1 =
        db
        |> Trie.new()
        |> Trie.update_key(<<0x01::4>>, "foo")
        |> Trie.update_key(<<0x01::4, 0x01::4>>, "bar")
        |> Trie.update_key(<<0x01::4, 0x01::4, 0x01::4, 0x02::4, 0x01::4, 0x03::4>>, "qux")
        |> Trie.update_key(key, "corge")

      trie_2 = Trie.update_key(trie_1, key, "grault")

      assert Trie.get_key(trie_2, key) == "grault"
    end

    test "a root of the trie depends only on the data", %{db: db} do
      trie1 =
        db
        |> Trie.new()
        |> Trie.update_key(<<4::4, 2::4, 3::4>>, 1)
        |> Trie.update_key(<<4::4, 2::4>>, 2)
        |> Trie.update_key(<<4::4, 2::4, 3::4, 8::4>>, 3)

      trie2 =
        db
        |> Trie.new()
        |> Trie.update_key(<<4::4, 2::4>>, 2)
        |> Trie.update_key(<<4::4, 2::4, 3::4, 8::4>>, 3)
        |> Trie.update_key(<<4::4, 2::4, 3::4>>, 1)

      assert trie2.root_hash == trie1.root_hash
    end

    test "a set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update_key(<<5::4, 7::4, 10::4, 15::4, 15::4>>, "a")
        |> Trie.update_key(<<5::4, 11::4, 0::4, 0::4, 14::4>>, "b")
        |> Trie.update_key(<<5::4, 10::4, 0::4, 0::4, 14::4>>, "c")
        |> Trie.update_key(<<4::4, 10::4, 0::4, 0::4, 14::4>>, "d")
        |> Trie.update_key(<<5::4, 10::4, 1::4, 0::4, 14::4>>, "e")

      assert Trie.get_key(trie, <<5::4, 7::4, 10::4, 15::4, 15::4>>) == "a"
      assert Trie.get_key(trie, <<5::4, 11::4, 0::4, 0::4, 14::4>>) == "b"
      assert Trie.get_key(trie, <<5::4, 10::4, 0::4, 0::4, 14::4>>) == "c"
      assert Trie.get_key(trie, <<4::4, 10::4, 0::4, 0::4, 14::4>>) == "d"
      assert Trie.get_key(trie, <<5::4, 10::4, 1::4, 0::4, 14::4>>) == "e"
    end

    test "yet another set of updates", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update_key(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update_key(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update_key(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get_key(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get_key(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get_key(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "yet another set of updates now in memory", %{db: db} do
      trie =
        db
        |> Trie.new()
        |> Trie.update_key(
          <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4, 10::4,
            6::4, 7::4, 1::4>>,
          "a"
        )
        |> Trie.update_key(
          <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4, 8::4,
            5::4, 2::4, 12::4>>,
          "b"
        )
        |> Trie.update_key(
          <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4, 6::4,
            4::4, 5::4, 0::4>>,
          "c"
        )

      assert Trie.get_key(
               trie,
               <<15::4, 10::4, 5::4, 11::4, 5::4, 2::4, 10::4, 9::4, 6::4, 13::4, 10::4, 3::4,
                 10::4, 6::4, 7::4, 1::4>>
             ) == "a"

      assert Trie.get_key(
               trie,
               <<15::4, 11::4, 1::4, 14::4, 9::4, 7::4, 9::4, 5::4, 6::4, 15::4, 6::4, 11::4,
                 8::4, 5::4, 2::4, 12::4>>
             ) == "b"

      assert Trie.get_key(
               trie,
               <<6::4, 1::4, 10::4, 10::4, 5::4, 7::4, 14::4, 3::4, 10::4, 0::4, 15::4, 3::4,
                 6::4, 4::4, 5::4, 0::4>>
             ) == "c"
    end

    test "remove branch value", %{db: db} do
      empty_trie = Trie.new(db)
      trie_1 = Trie.update_key(empty_trie, <<0x01::4, 0x02::4>>, "foo")
      trie_2 = Trie.update_key(trie_1, <<0x01::4, 0x02::4, 0x03::4>>, "bar")
      trie_3 = Trie.remove_key(trie_2, <<0x01::4, 0x02::4>>)

      assert Trie.get_key(trie_3, <<0x01::4, 0x02::4>>) == nil
      assert Trie.get_key(trie_3, <<0x01::4, 0x02::4, 0x03::4>>) == "bar"
    end

    test "acceptence testing", %{db: db} do
      {trie, values} =
        Enum.reduce(1..100, {Trie.new(db), []}, fn _, {trie, dict} ->
          key = random_key()
          value = random_value()

          updated_trie = Trie.update_key(trie, key, value)

          # Verify each key exists in our trie
          for {k, v} <- dict do
            assert Trie.get_key(updated_trie, k) == v
          end

          {updated_trie, [{key, value} | dict]}
        end)

      # next, assert tree is well formed
      assert Verifier.verify_trie(trie, values) == :ok
    end

    test "creates 2 tries with the same key-value pairs but different insertion order", %{db: db} do
      key_value_pairs = [
        {"elixir", "erlang"},
        {"kotlin", "java"},
        {"purescript", "javascript"},
        {"rust", "c++"},
        {"ruby", "crystal"}
      ]

      trie1 =
        Enum.reduce(key_value_pairs, Trie.new(db), fn {lang1, lang2}, trie_acc ->
          Trie.update_key(trie_acc, lang1, lang2)
        end)

      trie2 =
        key_value_pairs
        |> Enum.reverse()
        |> Enum.reduce(Trie.new(db), fn {lang1, lang2}, trie_acc ->
          Trie.update_key(trie_acc, lang1, lang2)
        end)

      trie3 =
        key_value_pairs
        |> Enum.shuffle()
        |> Enum.reduce(Trie.new(db), fn {lang1, lang2}, trie_acc ->
          Trie.update_key(trie_acc, lang1, lang2)
        end)

      assert trie1.root_hash == trie2.root_hash
      assert trie1.root_hash == trie3.root_hash
    end
  end
end
