defmodule EvmTest do
  alias MerklePatriciaTree.Trie
  use ExUnit.Case, async: true

  @passing_tests_by_group %{
    sha3: :all,
    arithmetic: :all,
    bitwise_logic_operation: :all,
    push_dup_swap: :all,
    i_oand_flow_operations: :all,
  }


  test "Ethereum Common Tests" do
    for {test_group_name, _test_group} <- @passing_tests_by_group do
      for {_test_name, test} <- passing_tests(test_group_name) do
        state = EVM.VM.run(
          state(test),
          hex_to_int(test["exec"]["gas"]),
          %EVM.ExecEnv{
            machine_code: hex_to_binary(test["exec"]["code"]),
            sender: hex_to_binary(test["exec"]["caller"]),
            block_interface: block_interface(test),
            data: hex_to_binary(test["exec"]["data"]),
            value_in_wei: hex_to_binary(test["exec"]["value"]),
          }
        )


        assert_state(test, state)

        if test["gas"] do
          assert hex_to_int(test["gas"]) == elem(state, 1) 
        end
      end
    end
  end

  def state(test) do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    state = test["pre"]
      |> Enum.reduce(%{}, fn({key, value}, storage) ->
        Map.merge(storage, value["storage"])
      end
      )
      |> Enum.reduce(state, fn({key, value}, state) ->
        Trie.update(state, <<hex_to_int(key)::size(256)>>, <<hex_to_int(value)::size(256)>>)
      end)
  end

  def block_interface(test) do
    block_interface = EVM.Interface.Mock.MockBlockInterface.new(
      %Block.Header{
        number: hex_to_int(test["env"]["currentNumber"]),
        timestamp: hex_to_int(test["env"]["currentTimestamp"]),
        gas_limit: hex_to_int(test["env"]["currentGasLimit"]),
        difficulty: hex_to_int(test["env"]["currentDifficulty"]),
      }
    )
  end

  def passing_tests(test_group_name) do
    read_test_file(test_group_name)
      |> Enum.filter(fn({test_name, _test}) ->
        passing_tests_in_group = Map.get(@passing_tests_by_group, test_group_name)

        passing_tests_in_group == :all ||
          Enum.member?(passing_tests_in_group, String.to_atom(test_name))
      end)
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
    assert expected_state(test) == actual_state(state)
  end

  def expected_state(test) do
    contract_address = Map.get(Map.get(test, "exec"), "address")
    test
      |> Map.get("post", %{})
      |> Map.get(contract_address, %{})
      |> Map.get("storage", %{})
      |> Enum.map(fn {k, v} ->
        {hex_to_binary(k), hex_to_binary(v)}
      end)
  end

  def actual_state(state) do
    state = state
      |> elem(0)

    if state do
      state
      |> MerklePatriciaTree.Trie.Inspector.all_values()
      |> Enum.map(fn {k, v} -> {r_trim(k), r_trim(v)} end)
    else
      []
    end
  end

  def r_trim(n), do: n
    |> :binary.decode_unsigned
    |> :binary.encode_unsigned
end
