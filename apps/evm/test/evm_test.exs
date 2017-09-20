defmodule EvmTest do
  alias MerklePatriciaTree.Trie
  use ExUnit.Case, async: true

  @passing_tests_by_group %{
    sha3: :all,
    arithmetic: :all,
    bitwise_logic_operation: :all,
    block_info: :all,
    environmental_info: [
      :ExtCodeSizeAddressInputTooBigLeftMyAddress,
      :ExtCodeSizeAddressInputTooBigRightMyAddress,
      :address0,
      :address1,
      :balance0,
      :balance01,
      :balance1,
      :balanceAddress2,
      :balanceAddressInputTooBig,
      :balanceAddressInputTooBigLeftMyAddress,
      :balanceAddressInputTooBigRightMyAddress,
      :balanceCaller3,
      :calldatacopy0,
      :calldatacopy0_return,
      :calldatacopy1,
      :calldatacopy1_return,
      :calldatacopy2,
      :calldatacopy2_return,
      :calldatacopyUnderFlow,
      :calldatacopyZeroMemExpansion,
      :calldatacopyZeroMemExpansion_return,
      :calldatacopy_DataIndexTooHigh,
      :calldatacopy_DataIndexTooHigh2,
      :calldatacopy_DataIndexTooHigh2_return,
      :calldatacopy_DataIndexTooHigh_return,
      :calldatacopy_sec,
      :calldataload0,
      :calldataload1,
      :calldataload2,
      :calldataloadSizeTooHigh,
      :calldataloadSizeTooHighPartial,
      :calldataload_BigOffset,
      :calldatasize0,
      :calldatasize1,
      :calldatasize2,
      :caller,
      :callvalue,
      :codecopy0,
      :codecopyZeroMemExpansion,
      :codecopy_DataIndexTooHigh,
      :codesize,
      :extcodecopy0,
      :extcodecopy0AddressTooBigLeft,
      :extcodecopy0AddressTooBigRight,
      :extcodecopyZeroMemExpansion,
      :extcodecopy_DataIndexTooHigh,
      :extcodesize0,
      :extcodesize1,
      :extcodesizeUnderFlow,
      :gasprice,
      :origin,

      # :env1,
    ],
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
            account_interface: account_interface(test),
            address: hex_to_binary(test["exec"]["address"]),
            block_interface: block_interface(test),
            data: hex_to_binary(test["exec"]["data"]),
            gas_price: hex_to_binary(test["exec"]["gasPrice"]),
            machine_code: hex_to_binary(test["exec"]["code"]),
            originator: hex_to_binary(test["exec"]["origin"]),
            sender: hex_to_binary(test["exec"]["caller"]),
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

  def account_interface(test) do
    account_map = %{
      hex_to_int(test["exec"]["caller"]) => %{
        balance: 0,
        code: hex_to_int(test["exec"]["code"]),
        nonce: 0,
    }}
    account_map = Enum.reduce(test["pre"], account_map, fn({address, account}, address_map) ->
      Map.merge(address_map, %{
          hex_to_int(address) => %{
            balance: hex_to_int(account["balance"]),
            code: hex_to_int(account["code"]),
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
    block_interface = EVM.Interface.Mock.MockBlockInterface.new(
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
