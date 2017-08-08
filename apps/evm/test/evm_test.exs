defmodule EvmTest do
  use ExUnit.Case, async: true

  @passing_tests %{
    arithmetic: [
      :add0,
      :add1,
    ]
  }


  test "Ethereum Common Tests" do
    for {test_type, test_group} <- @passing_tests do
      for {test_name, test} <- read_test_file(test_type),
        Enum.member?(test_group, String.to_atom(test_name)) do
        db = MerklePatriciaTree.Test.random_ets_db()
        state = EVM.VM.run(
          MerklePatriciaTree.Trie.new(db),
          hex_to_int(test["exec"]["gas"]),
          %EVM.ExecEnv{
            machine_code: hex_to_binary(test["exec"]["code"]),
          }
        )

        assert_state(test, state)
        assert elem(state, 1) == hex_to_int(test["gas"])
      end
    end
  end

  def read_test_file(type) do
    {:ok, body} = File.read(test_file_name(type))
    Poison.decode!(body)
  end

  def test_file_name(type) do
    "test/support/ethereum_common_tests/VMTests/vm#{Macro.camelize(Atom.to_string(type))}Test.json"
  end

  def hex_to_binary(string) do
    string
    |> String.slice(2..-1)
    |> Base.decode16!(case: :mixed)
  end

  def hex_to_int(string) do
    hex_to_binary(string)
    |> :binary.decode_unsigned
  end

  def assert_state(test, state) do
    contract_address = Map.get(Map.get(test, "exec"), "address")
    assert (test
      |> Map.get("post")
      |> Map.get(contract_address)
      |> Map.get("storage")
      |> Enum.map(fn {k, v} ->
        {hex_to_binary(k), hex_to_binary(v)}
      end)) == state
      |> elem(0)
      |> MerklePatriciaTree.Trie.Inspector.all_values()
      |> Enum.map(fn {k, v} -> {r_trim(k), r_trim(v)} end)
  end

  def r_trim(n), do: n
    |> :binary.decode_unsigned
    |> :binary.encode_unsigned
end
