defmodule EvmTest do
  alias MerklePatriciaTree.Trie
  use ExUnit.Case, async: true

  @passing_tests_by_group %{
    sha3: :all,
    arithmetic: :all,
    bitwise_logic_operation: :all,
    block_info: :all,
    environmental_info: :all,
    push_dup_swap: :all,
    i_oand_flow_operations: :all,
    system_operations: [
      :ABAcalls0,
      :ABAcalls1,
      :ABAcalls2,
      :ABAcalls3,
      :ABAcallsSuicide0,
      :ABAcallsSuicide1,
      :CallRecursiveBomb0,
      :CallRecursiveBomb1,
      :CallRecursiveBomb2,
      :CallRecursiveBomb3,
      :CallToNameRegistrator0,
      :CallToNameRegistratorNotMuchMemory0,
      :CallToNameRegistratorNotMuchMemory1,
      :CallToNameRegistratorOutOfGas,
      :CallToNameRegistratorTooMuchMemory0,
      :CallToNameRegistratorTooMuchMemory1,
      :CallToNameRegistratorTooMuchMemory2,
      :CallToReturn1,
      :PostToNameRegistrator0,
      :PostToReturn1,
      :TestNameRegistrator,
      :callstatelessToNameRegistrator0,
      :callstatelessToReturn1,
      :createNameRegistratorOutOfMemoryBonds0,
      :createNameRegistratorOutOfMemoryBonds1,
      :return0,
      :return1,
      :suicide0,
      :suicideNotExistingAccount,
      :suicideSendEtherToMe,

      # :CallToPrecompiledContract,
      # :callcodeToNameRegistrator0,
      # :callcodeToReturn1,
      # :createNameRegistrator,
      # :createNameRegistratorValueTooHigh,
      # :return2,
    ],
  }


  test "Ethereum Common Tests" do
    for {test_group_name, _test_group} <- @passing_tests_by_group do
      for {test_name, test} <- passing_tests(test_group_name) do
        {state, gas, _, _} = EVM.VM.run(
          state(test),
          hex_to_int(test["exec"]["gas"]),
          %EVM.ExecEnv{
            account_interface: account_interface(test),
            address: hex_to_int(test["exec"]["address"]),
            contract_interface: contract_interface(test),
            block_interface: block_interface(test),
            data: hex_to_binary(test["exec"]["data"]),
            gas_price: hex_to_binary(test["exec"]["gasPrice"]),
            machine_code: hex_to_binary(test["exec"]["code"]),
            originator: hex_to_binary(test["exec"]["origin"]),
            sender: hex_to_int(test["exec"]["caller"]),
            value_in_wei: hex_to_binary(test["exec"]["value"]),
          }
        )

        assert_state(test, state)

        if test["gas"] do
          assert hex_to_int(test["gas"]) == gas
        end
      end
    end
  end

  def state(test) do
    db = MerklePatriciaTree.Test.random_ets_db()
    for {address, value} <- test["pre"], into: %{} do
      {hex_to_int(address), account_state(value, db)}
    end
  end

  def account_state(account, db) do
    for {key, value} <- account, into: %{} do
      value = if key == "storage", do: account_storage(value, db), else: value
      {String.to_atom(key), value}
    end
  end

  def account_storage(storage, db) do
    Enum.reduce(storage, Trie.new(db), fn({key, value}, trie) ->
      Trie.update(trie, <<hex_to_int(key)::size(256)>>, <<hex_to_int(value)::size(256)>>)
    end)
  end

  def contract_interface(test) do
    EVM.Interface.Mock.MockContractInterface.new(
      state(test),
      0,
      %EVM.SubState{},
      <<>>
    )
  end

  def account_interface(test) do
    account_map = %{
      hex_to_int(test["exec"]["caller"]) => %{
        balance: 0,
        code: hex_to_binary(test["exec"]["code"]),
        nonce: 0,
    }}
    account_map = Enum.reduce(test["pre"], account_map, fn({address, account}, address_map) ->
      Map.merge(address_map, %{
          hex_to_int(address) => %{
            balance: hex_to_int(account["balance"]),
            code: hex_to_binary(account["code"]),
            nonce: hex_to_int(account["nonce"]),
          }
        })
    end)

    EVM.Interface.Mock.MockAccountInterface.new(%{
      account_map: account_map
    })
  end

  def block_interface(test) do
    genisis_block_header = %Block.Header{
      number: 0,
      mix_hash: 0,
    }

    first_block_header = %Block.Header{
      number: 1,
      mix_hash: 0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6
    }

    second_block_header = %Block.Header{
      number: 2,
      mix_hash: 0xad7c5bef027816a800da1736444fb58a807ef4c9603b7848673f7e3a68eb14a5,
    }

    parent_block_header = %Block.Header{
      number: hex_to_int(test["env"]["currentNumber"]) - 1,
      mix_hash: 0x6ca54da2c4784ea43fd88b3402de07ae4bced597cbb19f323b7595857a6720ae,
    }


    last_block_header = %Block.Header{
      number: hex_to_int(test["env"]["currentNumber"]),
      timestamp: hex_to_int(test["env"]["currentTimestamp"]),
      beneficiary: hex_to_int(test["env"]["currentCoinbase"]),
      mix_hash: 0,
      parent_hash: hex_to_int(test["env"]["currentNumber"]) - 1,
      gas_limit: hex_to_int(test["env"]["currentGasLimit"]),
      difficulty: hex_to_int(test["env"]["currentDifficulty"]),
    }

    block_map = %{
      genisis_block_header.mix_hash => genisis_block_header,
      first_block_header.mix_hash => first_block_header,
      second_block_header.mix_hash => second_block_header,
      parent_block_header.mix_hash => parent_block_header,
      last_block_header.mix_hash => last_block_header,
    }

    EVM.Interface.Mock.MockBlockInterface.new(
      last_block_header,
      block_map
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
    if Map.get(test, "post") do
      assert expected_state(test) == actual_state(state)
    end
  end

  def expected_state(test) do
    post = Map.get(test, "post", %{})

    for {address, account_state} <- post, into: %{} do
      storage = Map.get(account_state, "storage")
      storage = for {key, value} <- storage, into: %{} do
        {hex_to_binary(key), hex_to_binary(value)}
      end

      {hex_to_int(address), storage}
    end
  end

  def actual_state(state) do
    for {address, account_state} <- state, into: %{} do
      storage = Map.get(account_state, :storage)
        |> MerklePatriciaTree.Trie.Inspector.all_values()
        |> Enum.reduce(%{}, fn ({key, value}, state) ->
          Map.put(state, r_trim(key), r_trim(value))
        end)

      {address, storage}
    end
  end

  def r_trim(n), do: n
    |> :binary.decode_unsigned
    |> :binary.encode_unsigned
end
