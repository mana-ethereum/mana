defmodule EvmTest do
  use ExUnit.Case, async: true

  @passing_tests_by_group %{
    sha3: :all,
    arithmetic: :all,
    bitwise_logic_operation: :all,
    push_dup_swap: :all,
    i_oand_flow_operations: [
      :byte1,
      :jump1,
      :jumpi0,
      :log1MemExp,
      :memory1,
      :mstore0,
      :mstore1,
      :mstore8MemExp,
      :mstore8WordToBigError,
      :mstore8_0,
      :mstore8_1,
      :mstoreMemExp,
      :mstoreWordToBigError,
      :mstore_mload0,
      :pop0,
      :pop1,
      :sha3MemExp,
      :sstore_load_0,
      :sstore_load_1,
      :sstore_load_2,

      # :mloadError0,
      # :mloadError1,
      # :mloadMemExp,
      # :mloadOutOfGasError2,
      # :msize0,
      # :msize1,
      # :msize2,
      # :msize3,
      # :pc0,
      # :pc1,
      # :return1,
      # :return2,
      # :BlockNumberDynamicJump0_AfterJumpdest,
      # :BlockNumberDynamicJump0_AfterJumpdest3,
      # :BlockNumberDynamicJump0_foreverOutOfGas,
      # :BlockNumberDynamicJump0_jumpdest0,
      # :BlockNumberDynamicJump0_jumpdest2,
      # :BlockNumberDynamicJump0_withoutJumpdest,
      # :BlockNumberDynamicJump1,
      # :BlockNumberDynamicJumpInsidePushWithJumpDest,
      # :BlockNumberDynamicJumpInsidePushWithoutJumpDest,
      # :BlockNumberDynamicJumpi0,
      # :BlockNumberDynamicJumpi1,
      # :BlockNumberDynamicJumpi1_jumpdest,
      # :BlockNumberDynamicJumpiAfterStop,
      # :BlockNumberDynamicJumpiOutsideBoundary,
      # :BlockNumberDynamicJumpifInsidePushWithJumpDest,
      # :BlockNumberDynamicJumpifInsidePushWithoutJumpDest,
      # :DyanmicJump0_outOfBoundary,
      # :DynamicJump0_AfterJumpdest,
      # :DynamicJump0_AfterJumpdest3,
      # :DynamicJump0_foreverOutOfGas,
      # :DynamicJump0_jumpdest0,
      # :DynamicJump0_jumpdest2,
      # :DynamicJump0_withoutJumpdest,
      # :DynamicJump1,
      # :DynamicJumpAfterStop,
      # :DynamicJumpInsidePushWithJumpDest,
      # :DynamicJumpInsidePushWithoutJumpDest,
      # :DynamicJumpJD_DependsOnJumps0,
      # :DynamicJumpJD_DependsOnJumps1,
      # :DynamicJumpPathologicalTest0,
      # :DynamicJumpPathologicalTest1,
      # :DynamicJumpPathologicalTest2,
      # :DynamicJumpPathologicalTest3,
      # :DynamicJumpStartWithJumpDest,
      # :DynamicJump_value1,
      # :DynamicJump_value2,
      # :DynamicJump_value3,
      # :DynamicJump_valueUnderflow,
      # :DynamicJumpi0,
      # :DynamicJumpi1,
      # :DynamicJumpi1_jumpdest,
      # :DynamicJumpiAfterStop,
      # :DynamicJumpiOutsideBoundary,
      # :DynamicJumpifInsidePushWithJumpDest,
      # :DynamicJumpifInsidePushWithoutJumpDest,
      # :JDfromStorageDynamicJump0_AfterJumpdest,
      # :JDfromStorageDynamicJump0_AfterJumpdest3,
      # :JDfromStorageDynamicJump0_foreverOutOfGas,
      # :JDfromStorageDynamicJump0_jumpdest0,
      # :JDfromStorageDynamicJump0_jumpdest2,
      # :JDfromStorageDynamicJump0_withoutJumpdest,
      # :JDfromStorageDynamicJump1,
      # :JDfromStorageDynamicJumpInsidePushWithJumpDest,
      # :JDfromStorageDynamicJumpInsidePushWithoutJumpDest,
      # :JDfromStorageDynamicJumpi0,
      # :JDfromStorageDynamicJumpi1,
      # :JDfromStorageDynamicJumpi1_jumpdest,
      # :JDfromStorageDynamicJumpiAfterStop,
      # :JDfromStorageDynamicJumpiOutsideBoundary,
      # :JDfromStorageDynamicJumpifInsidePushWithJumpDest,
      # :JDfromStorageDynamicJumpifInsidePushWithoutJumpDest,
      # :bad_indirect_jump1,
      # :bad_indirect_jump2,
      # :calldatacopyMemExp,
      # :codecopyMemExp,
      # :deadCode_1,
      # :dupAt51becameMload,
      # :extcodecopyMemExp,
      # :for_loop1,
      # :for_loop2,
      # :gas0,
      # :gas1,
      # :gasOverFlow,
      # :indirect_jump1,
      # :indirect_jump2,
      # :indirect_jump3,
      # :indirect_jump4,
      # :jump0_AfterJumpdest,
      # :jump0_AfterJumpdest3,
      # :jump0_foreverOutOfGas,
      # :jump0_jumpdest0,
      # :jump0_jumpdest2,
      # :jump0_outOfBoundary,
      # :jump0_withoutJumpdest,
      # :jumpAfterStop,
      # :jumpDynamicJumpSameDest,
      # :jumpHigh,
      # :jumpInsidePushWithJumpDest,
      # :jumpInsidePushWithoutJumpDest,
      # :jumpOntoJump,
      # :jumpTo1InstructionafterJump,
      # :jumpTo1InstructionafterJump_jumpdestFirstInstruction,
      # :jumpTo1InstructionafterJump_noJumpDest,
      # :jumpToUint64maxPlus1,
      # :jumpToUintmaxPlus1,
      # :jumpdestBigList,
      # :jumpi1,
      # :jumpi1_jumpdest,
      # :jumpiAfterStop,
      # :jumpiOutsideBoundary,
      # :jumpiToUint64maxPlus1,
      # :jumpiToUintmaxPlus1,
      # :jumpi_at_the_end,
      # :jumpifInsidePushWithJumpDest,
      # :jumpifInsidePushWithoutJumpDest,
      # :kv1,
      # :loop_stacklimit_1020,
      # :loop_stacklimit_1021,
      # :sstore_underflow,
      # :stack_loop,
      # :stackjump1,
      # :swapAt52becameMstore,
      # :when
  ]
  }


  test "Ethereum Common Tests" do
    for {test_group_name, _test_group} <- @passing_tests_by_group do
      for {_test_name, test} <- passing_tests(test_group_name) do
        db = MerklePatriciaTree.Test.random_ets_db()
        state = EVM.VM.run(
          MerklePatriciaTree.Trie.new(db),
          hex_to_int(test["exec"]["gas"]),
          %EVM.ExecEnv{
            machine_code: hex_to_binary(test["exec"]["code"]),
            data: hex_to_binary(test["exec"]["data"]),
          }
        )

        assert_state(test, state)

        if test["gas"] do
          assert hex_to_int(test["gas"]) == elem(state, 1) 
        end
      end
    end
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
