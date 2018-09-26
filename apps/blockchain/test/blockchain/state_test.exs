defmodule Blockchain.StateTest do
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account

  use EthCommonTest.Harness
  use ExUnit.Case, async: true

  @failing_tests %{
    "Byzantium" => [
      "stReturnDataTest/call_outsize_then_create_successful_then_returndatasize",
      "stReturnDataTest/call_then_call_value_fail_then_returndatasize",
      "stReturnDataTest/call_then_create_successful_then_returndatasize",
      "stReturnDataTest/modexp_modsize0_returndatasize",
      "stReturnDataTest/returndatacopy_afterFailing_create",
      "stReturnDataTest/returndatacopy_after_revert_in_staticcall",
      "stReturnDataTest/returndatacopy_after_successful_callcode",
      "stReturnDataTest/returndatacopy_after_successful_delegatecall",
      "stReturnDataTest/returndatacopy_after_successful_staticcall",
      "stReturnDataTest/returndatacopy_following_call",
      "stReturnDataTest/returndatacopy_following_revert",
      "stReturnDataTest/returndatacopy_following_revert_in_create",
      "stRevertTest/PythonRevertTestTue201814-1430",
      "stRevertTest/RevertInCallCode",
      "stRevertTest/RevertInCreateInInit",
      "stRevertTest/RevertInDelegateCall",
      "stRevertTest/RevertOpcodeInCreateReturns",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stSpecialTest/failed_tx_xcf416c53",
      "stStaticCall/static_Call1024PreCalls2",
      "stTransactionTest/EmptyTransaction2",
      "stZeroKnowledge2/ecmul_0-3_5616_28000_96"
    ],
    "Constantinople" => [
      "stCreate2/RevertDepthCreate2OOG",
      "stCreate2/RevertDepthCreateAddressCollision",
      "stCreate2/RevertInCreateInInit",
      "stCreate2/RevertOpcodeCreate",
      "stCreate2/RevertOpcodeInCreateReturns",
      "stCreate2/call_outsize_then_create2_successful_then_returndatasize",
      "stCreate2/call_then_create2_successful_then_returndatasize",
      "stCreate2/create2InitCodes",
      "stCreate2/create2SmartInitCode",
      "stCreate2/create2callPrecompiles",
      "stCreate2/create2checkFieldsInInitcode",
      "stCreate2/create2collisionBalance",
      "stCreate2/create2collisionStorage",
      "stCreate2/returndatacopy_afterFailing_create",
      "stCreate2/returndatacopy_following_revert_in_create",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stZeroKnowledge2/ecmul_0-3_5616_28000_96"
    ],
    "EIP150" => [
      "stInitCodeTest/NotEnoughCashContractCreation",
      "stInitCodeTest/OutOfGasContractCreation",
      "stInitCodeTest/OutOfGasPrefundedContractCreation",
      "stRandom2/201503110226PYTHON_DUP6",
      "stRevertTest/RevertOpcodeInInit",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stTransactionTest/CreateTransactionReverted",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAfter",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAt",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasBefore"
    ],
    "EIP158" => [
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stSpecialTest/failed_tx_xcf416c53",
      "stTransactionTest/EmptyTransaction2"
    ],
    "Frontier" => [
      "stCallCreateCallCodeTest/createNameRegistratorPerTxsNotEnoughGas",
      "stInitCodeTest/NotEnoughCashContractCreation",
      "stRandom2/201503110226PYTHON_DUP6",
      "stTransactionTest/CreateTransactionReverted",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost"
    ],
    "Homestead" => [
      "stDelegatecallTestHomestead/callOutput1",
      "stDelegatecallTestHomestead/callOutput2",
      "stDelegatecallTestHomestead/callOutput3",
      "stDelegatecallTestHomestead/callOutput3Fail",
      "stDelegatecallTestHomestead/callOutput3partial",
      "stDelegatecallTestHomestead/callOutput3partialFail",
      "stDelegatecallTestHomestead/callcodeOutput1",
      "stDelegatecallTestHomestead/callcodeOutput2",
      "stDelegatecallTestHomestead/callcodeOutput3",
      "stDelegatecallTestHomestead/callcodeOutput3Fail",
      "stDelegatecallTestHomestead/callcodeOutput3partial",
      "stDelegatecallTestHomestead/callcodeOutput3partialFail",
      "stInitCodeTest/NotEnoughCashContractCreation",
      "stInitCodeTest/OutOfGasContractCreation",
      "stInitCodeTest/OutOfGasPrefundedContractCreation",
      "stRandom/randomStatetest184",
      "stRandom/randomStatetest347",
      "stRandom2/201503110226PYTHON_DUP6",
      "stRevertTest/RevertOpcodeInInit",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stTransactionTest/CreateTransactionReverted",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAfter",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAt",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasBefore"
    ]
  }

  @fifteen_minutes 1000 * 60 * 15
  @num_test_groups 10

  @tag :ethereum_common_tests
  @tag :state_common_tests
  test "Blockchain state tests" do
    grouped_test_per_fork()
    |> Task.async_stream(&run_tests(&1), timeout: @fifteen_minutes)
    |> Enum.flat_map(fn {:ok, results} -> results end)
    |> make_assertions()
  end

  defp grouped_test_per_fork do
    for fork <- forks_with_existing_implementation(),
        test_group <- split_tests_into_groups(@num_test_groups),
        do: {fork, test_group}
  end

  defp split_tests_into_groups(num_groups_desired) do
    all_tests = tests()
    test_count = Enum.count(all_tests)
    tests_per_group = div(test_count, num_groups_desired)

    Enum.chunk_every(all_tests, tests_per_group)
  end

  defp run_tests({fork, tests}) do
    tests
    |> Stream.reject(&known_fork_failure?(&1, fork))
    |> Enum.flat_map(&StateTestRunner.run(&1, fork))
    |> Enum.filter(&failed_test?/1)
  end

  defp forks_with_existing_implementation do
    @failing_tests
    |> Map.keys()
    |> Enum.reject(&fork_without_implementation?/1)
  end

  defp fork_without_implementation?(fork) do
    fork
    |> configuration()
    |> is_nil()
  end

  def configuration(hardfork) do
    case hardfork do
      "Frontier" ->
        EVM.Configuration.Frontier.new()

      "Homestead" ->
        EVM.Configuration.Homestead.new()

      "EIP150" ->
        EVM.Configuration.EIP150.new()

      "EIP158" ->
        EVM.Configuration.EIP158.new()

      "Byzantium" ->
        EVM.Configuration.Byzantium.new()

      "Constantinople" ->
        EVM.Configuration.Constantinople.new()

      _ ->
        nil
    end
  end

  defp known_fork_failure?(json_test_path, hardfork) do
    test_name = test_name_with_group_from_path(json_test_path)
    failing_tests = Map.fetch!(@failing_tests, hardfork)

    Enum.member?(failing_tests, test_name)
  end

  defp test_name_with_group_from_path(path) do
    path_elements =
      path
      |> Path.rootname()
      |> Path.split()

    group_name = Enum.fetch!(path_elements, -2)
    test_name = Enum.fetch!(path_elements, -1)

    Path.join(group_name, test_name)
  end

  defp failed_test?(%{state_root_mismatch: true}), do: true
  defp failed_test?(%{logs_hash_mismatch: true}), do: true
  defp failed_test?(%{}), do: false

  defp make_assertions([]), do: assert(true)
  defp make_assertions(failing_tests), do: assert(false, failure_message(failing_tests))

  defp failure_message(failing_tests) do
    """
    #{state_root_failures_message(failing_tests)}
    =========================

    #{logs_hash_error_message(failing_tests)}
    """
  end

  defp state_root_failures_message(failing_tests) do
    state_root_mismatch_failures =
      Enum.filter(failing_tests, fn test -> test.state_root_mismatch end)

    total_count = Enum.count(state_root_mismatch_failures)

    state_root_error_messages =
      state_root_mismatch_failures
      |> Enum.map(&single_state_root_error_message/1)
      |> Enum.join("\n")

    """
    State root mismatch for the following tests:
    #{inspect(state_root_error_messages)}
    -----------------
    Total state root failures: #{inspect(total_count)}
    """
  end

  defp logs_hash_error_message(failing_tests) do
    logs_hash_mismatch_failures =
      Enum.filter(failing_tests, fn test -> test.logs_hash_mismatch end)

    total_count = Enum.count(logs_hash_mismatch_failures)

    logs_hash_error_messages =
      logs_hash_mismatch_failures
      |> Enum.map(&single_logs_hash_error_message/1)
      |> Enum.join("\n")

    """
    Logs hash mismatch for the following tests:
    #{inspect(logs_hash_error_messages)}
    -----------------
    Total logs hash failures: #{inspect(total_count)}
    """
  end

  defp single_logs_hash_error_message(test_result) do
    %{
      hardfork: hardfork,
      test_name: test_name,
      logs_hash_expected: expected,
      logs_hash_actual: actual
    } = test_result

    "[#{hardfork}] #{test_name}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  defp single_state_root_error_message(test_result) do
    %{
      hardfork: hardfork,
      test_name: test_name,
      state_root_expected: expected,
      state_root_actual: actual
    } = test_result

    "[#{hardfork}] #{test_name}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  def dump_state(state) do
    state
    |> Trie.Inspector.all_values()
    |> Enum.map(fn {key, value} ->
      k = Base.encode16(key, case: :lower)
      v = value |> ExRLP.decode() |> Account.deserialize()
      {k, v}
    end)
    |> Enum.map(fn {address_key, account} ->
      IO.puts(address_key)
      IO.puts("  Balance: #{account.balance}")
      IO.puts("  Nonce: #{account.nonce}")
      IO.puts("  Storage Root:")
      IO.puts("  " <> Base.encode16(account.storage_root))
      IO.puts("  Code Hash")
      IO.puts("  " <> Base.encode16(account.code_hash))
    end)
  end

  defp tests do
    ethereum_common_tests_path()
    |> Path.join("/GeneralStateTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
