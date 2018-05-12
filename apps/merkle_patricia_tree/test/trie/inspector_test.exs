defmodule MerklePatriciaTree.Trie.InspectorTest do
  use ExUnit.Case, async: true
  doctest MerklePatriciaTree.Trie.Inspector

  import ExUnit.CaptureIO
  import Support.NodeHelpers, only: :functions

  alias MerklePatriciaTree.Trie
  alias MerklePatriciaTree.Trie.{Storage, Inspector}

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()

    {:ok, %{db: db}}
  end

  defp assert_inspector(trie, expected) do
    assert capture_io(fn -> Inspector.inspect_trie(trie) end) == expected
  end

  describe "inspect_trie" do
    test "with just one leaf", %{db: db} do
      root_hash = leaf_node([0x01, 0x02, 0x03], "foo")
      trie = Trie.new(db, root_hash)

      expected = """
      ~~~Trie~~~
      Node: leaf ([1, 2, 3]="foo")
      ~~~/Trie/~~~

      """

      assert_inspector(trie, expected)
    end

    test "with an extension node followed by a leaf", %{db: db} do
      root_hash =
        [0x01, 0x02]
        |> extension_node(leaf_node([0x03], "bar"))
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      expected = """
      ~~~Trie~~~
      Node: ext (prefix: [1, 2])
        Node: leaf ([3]="bar")
      ~~~/Trie/~~~

      """

      assert_inspector(trie, expected)
    end

    test "with an extension node followed by an extension node and then leaf", %{db: db} do
      root_hash =
        [0x01, 0x02]
        |> extension_node(extension_node([0x03], leaf_node([0x04], "baz")))
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      expected = """
      ~~~Trie~~~
      Node: ext (prefix: [1, 2])
        Node: ext (prefix: [3])
          Node: leaf ([4]="baz")
      ~~~/Trie/~~~

      """

      assert_inspector(trie, expected)
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

      # E.g. decoded branch node:
      #
      # {:branch,
      #   [
      #     ["2", "hi"], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [],
      #     "cool"
      #  ]}

      root_hash =
        root_node
        |> ExRLP.encode()
        |> Storage.store(db)

      trie = Trie.new(db, root_hash)

      expected = """
      ~~~Trie~~~
      Node: ext (prefix: [1])
        Node: branch (value: "cool")
          [0] Node: leaf ([2]="hi")
          [1] Node: <empty>
          [2] Node: <empty>
          [3] Node: <empty>
          [4] Node: <empty>
          [5] Node: <empty>
          [6] Node: <empty>
          [7] Node: <empty>
          [8] Node: <empty>
          [9] Node: <empty>
          [10] Node: <empty>
          [11] Node: <empty>
          [12] Node: <empty>
          [13] Node: <empty>
          [14] Node: <empty>
          [15] Node: <empty>
      ~~~/Trie/~~~

      """

      assert_inspector(trie, expected)
    end
  end
end
