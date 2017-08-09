defmodule EvmTest do
  use ExUnit.Case, async: true

  @passing_tests %{
    arithmetic: [
      # :expXY,
      # :expXY_success,
      # :fibbonacci_unrolled,

      :add0,
      :add1,
      :add2,
      :add3,
      :add4,
      :addmod0,
      :addmod1,
      :addmod1_overflow2,
      :addmod1_overflow3,
      :addmod1_overflow4,
      :addmod1_overflowDiff,
      :addmod2,
      :addmod2_0,
      :addmod2_1,
      :addmod3,
      :addmod3_0,
      :addmodBigIntCast,
      :addmodDivByZero,
      :addmodDivByZero1,
      :addmodDivByZero2,
      :addmodDivByZero3,
      :arith1,
      :div1,
      :divBoostBug,
      :divByNonZero0,
      :divByNonZero1,
      :divByNonZero2,
      :divByNonZero3,
      :divByZero,
      :divByZero_2,
      :exp0,
      :exp1,
      :exp2,
      :exp3,
      :exp4,
      :exp5,
      :exp6,
      :exp7,
      :expPowerOf256Of256_0,
      :expPowerOf256Of256_1,
      :expPowerOf256Of256_10,
      :expPowerOf256Of256_11,
      :expPowerOf256Of256_12,
      :expPowerOf256Of256_13,
      :expPowerOf256Of256_14,
      :expPowerOf256Of256_15,
      :expPowerOf256Of256_16,
      :expPowerOf256Of256_17,
      :expPowerOf256Of256_18,
      :expPowerOf256Of256_19,
      :expPowerOf256Of256_2,
      :expPowerOf256Of256_20,
      :expPowerOf256Of256_21,
      :expPowerOf256Of256_22,
      :expPowerOf256Of256_23,
      :expPowerOf256Of256_24,
      :expPowerOf256Of256_25,
      :expPowerOf256Of256_26,
      :expPowerOf256Of256_27,
      :expPowerOf256Of256_28,
      :expPowerOf256Of256_29,
      :expPowerOf256Of256_3,
      :expPowerOf256Of256_30,
      :expPowerOf256Of256_31,
      :expPowerOf256Of256_32,
      :expPowerOf256Of256_33,
      :expPowerOf256Of256_4,
      :expPowerOf256Of256_5,
      :expPowerOf256Of256_6,
      :expPowerOf256Of256_7,
      :expPowerOf256Of256_8,
      :expPowerOf256Of256_9,
      :expPowerOf256_1,
      :expPowerOf256_10,
      :expPowerOf256_11,
      :expPowerOf256_12,
      :expPowerOf256_13,
      :expPowerOf256_14,
      :expPowerOf256_15,
      :expPowerOf256_16,
      :expPowerOf256_17,
      :expPowerOf256_18,
      :expPowerOf256_19,
      :expPowerOf256_2,
      :expPowerOf256_20,
      :expPowerOf256_21,
      :expPowerOf256_22,
      :expPowerOf256_23,
      :expPowerOf256_24,
      :expPowerOf256_25,
      :expPowerOf256_26,
      :expPowerOf256_27,
      :expPowerOf256_28,
      :expPowerOf256_29,
      :expPowerOf256_3,
      :expPowerOf256_30,
      :expPowerOf256_31,
      :expPowerOf256_32,
      :expPowerOf256_33,
      :expPowerOf256_4,
      :expPowerOf256_5,
      :expPowerOf256_6,
      :expPowerOf256_7,
      :expPowerOf256_8,
      :expPowerOf256_9,
      :expPowerOf2_128,
      :expPowerOf2_16,
      :expPowerOf2_2,
      :expPowerOf2_256,
      :expPowerOf2_32,
      :expPowerOf2_4,
      :expPowerOf2_64,
      :expPowerOf2_8,
      :mod0,
      :mod1,
      :mod2,
      :mod3,
      :mod4,
      :modByZero,
      :mul0,
      :mul1,
      :mul2,
      :mul3,
      :mul4,
      :mul5,
      :mul6,
      :mul7,
      :mulUnderFlow,
      :mulmod0,
      :mulmod1,
      :mulmod1_overflow,
      :mulmod1_overflow2,
      :mulmod1_overflow3,
      :mulmod1_overflow4,
      :mulmod2,
      :mulmod2_0,
      :mulmod2_1,
      :mulmod3,
      :mulmod3_0,
      :mulmod4,
      :mulmoddivByZero,
      :mulmoddivByZero1,
      :mulmoddivByZero2,
      :mulmoddivByZero3,
      :not1,
      :sdiv0,
      :sdiv1,
      :sdiv2,
      :sdiv3,
      :sdiv4,
      :sdiv5,
      :sdiv6,
      :sdiv7,
      :sdiv8,
      :sdiv9,
      :sdivByZero0,
      :sdivByZero1,
      :sdivByZero2,
      :sdiv_dejavu,
      :sdiv_i256min,
      :sdiv_i256min2,
      :sdiv_i256min3,
      :signextendInvalidByteNumber,
      :signextend_00,
      :signextend_0_BigByte,
      :signextend_AlmostBiggestByte,
      :signextend_BigByteBigByte,
      :signextend_BigBytePlus1_2,
      :signextend_BigByte_0,
      :signextend_BitIsNotSet,
      :signextend_BitIsNotSetInHigherByte,
      :signextend_BitIsSetInHigherByte,
      :signextend_Overflow_dj42,
      :signextend_bigBytePlus1,
      :signextend_bitIsSet,
      :smod0,
      :smod1,
      :smod2,
      :smod3,
      :smod4,
      :smod5,
      :smod6,
      :smod7,
      :smod8_byZero,
      :smod_i256min1,
      :smod_i256min2,
      :stop,
      :sub0,
      :sub1,
      :sub2,
      :sub3,
      :sub4,
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

        if test["gas"] do
          assert hex_to_int(test["gas"]) == elem(state, 1) 
        end
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
