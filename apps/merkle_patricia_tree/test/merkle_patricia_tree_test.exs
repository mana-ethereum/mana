defmodule MerklePatriciaTreeTest do
  use ExUnit.Case

  alias ExthCrypto.Math
  alias MerklePatriciaTree.Trie

  @ethereum_common_tests_path "../../ethereum_common_tests"
  @passing_tests %{
    anyorder: :all,
    test: :all
  }

  test "Ethereum Common Tests" do
    for {test_type, test_group} <- @passing_tests do
      for {test_name, test} <- read_test_file(test_type),
          test_group == :all or Enum.member?(test_group, String.to_atom(test_name)) do
        db = MerklePatriciaTree.Test.random_ets_db()
        test_in = test["in"]

        input =
          if is_map(test_in) do
            test_in
            |> Enum.into([])
            |> Enum.map(fn {a, b} -> [a, b] end)
            |> Enum.shuffle()
          else
            test_in
          end

        trie =
          Enum.reduce(input, Trie.new(db), fn [k, v], trie ->
            Trie.update_key(trie, hex_to_bin(k), hex_to_bin(v))
          end)

        assert trie.root_hash == hex_to_bin(test["root"])
      end
    end
  end

  def hex_to_bin(hex = "0x" <> _str), do: Math.hex_to_bin(hex)
  def hex_to_bin(x), do: x

  def read_test_file(type) do
    {:ok, body} = File.read(test_file_name(type))
    Jason.decode!(body)
  end

  def test_file_name(type) do
    "#{@ethereum_common_tests_path}/TrieTests/trie#{Atom.to_string(type)}.json"
  end
end
