defmodule Blockchain.StateTest do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Transaction}
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Account.Storage
  alias ExthCrypto.Hash.Keccak

  use EthCommonTest.Harness
  use ExUnit.Case, async: true

  @failing_tests %{
    "Byzantium" => [
      "stBugs/returndatacopyPythonBug_Tue_03_48_41-1432",
      "stCreateTest/CreateOOGafterInitCodeReturndata",
      "stRandom2/randomStatetest647",
      "stReturnDataTest/call_outsize_then_create_successful_then_returndatasize",
      "stReturnDataTest/call_then_call_value_fail_then_returndatasize",
      "stReturnDataTest/call_then_create_successful_then_returndatasize",
      "stReturnDataTest/modexp_modsize0_returndatasize",
      "stReturnDataTest/returndatacopy_afterFailing_create",
      "stReturnDataTest/returndatacopy_after_failing_callcode",
      "stReturnDataTest/returndatacopy_after_failing_staticcall",
      "stReturnDataTest/returndatacopy_after_revert_in_staticcall",
      "stReturnDataTest/returndatacopy_after_successful_callcode",
      "stReturnDataTest/returndatacopy_after_successful_delegatecall",
      "stReturnDataTest/returndatacopy_after_successful_staticcall",
      "stReturnDataTest/returndatacopy_following_call",
      "stReturnDataTest/returndatacopy_following_create",
      "stReturnDataTest/returndatacopy_following_failing_call",
      "stReturnDataTest/returndatacopy_following_revert",
      "stReturnDataTest/returndatacopy_following_revert_in_create",
      "stReturnDataTest/returndatacopy_following_successful_create",
      "stReturnDataTest/returndatacopy_following_too_big_transfer",
      "stReturnDataTest/returndatacopy_initial",
      "stReturnDataTest/returndatacopy_initial_256",
      "stReturnDataTest/returndatacopy_overrun",
      "stRevertTest/PythonRevertTestTue201814-1430",
      "stRevertTest/RevertInCallCode",
      "stRevertTest/RevertInCreateInInit",
      "stRevertTest/RevertInDelegateCall",
      "stRevertTest/RevertOpcodeInCallsOnNonEmptyReturnData",
      "stRevertTest/RevertOpcodeInCreateReturns",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stSpecialTest/failed_tx_xcf416c53",
      "stStaticCall/static_Call1024PreCalls2",
      "stStaticCall/static_CallEcrecover0_0input",
      "stStaticCall/static_PostToReturn1",
      "stStaticCall/static_RevertOpcodeCalls",
      "stStaticCall/static_callWithHighValueAndOOGatTxLevel",
      "stTransactionTest/EmptyTransaction2",
      "stZeroKnowledge/ecmul_1-2_2_28000_128",
      "stZeroKnowledge/ecmul_1-2_2_28000_96",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge/ecmul_1-2_5616_21000_128",
      "stZeroKnowledge/ecmul_1-2_5616_21000_96",
      "stZeroKnowledge/ecmul_1-2_5616_28000_128",
      "stZeroKnowledge/ecmul_1-2_5617_21000_128",
      "stZeroKnowledge/ecmul_1-2_5617_21000_96",
      "stZeroKnowledge/ecmul_1-2_5617_28000_128",
      "stZeroKnowledge/ecmul_1-2_5617_28000_96",
      "stZeroKnowledge/ecmul_1-2_616_28000_96",
      "stZeroKnowledge/ecmul_1-2_9935_21000_128",
      "stZeroKnowledge/ecmul_1-2_9935_21000_96",
      "stZeroKnowledge/ecmul_1-2_9935_28000_128",
      "stZeroKnowledge/ecmul_1-2_9935_28000_96",
      "stZeroKnowledge/ecmul_1-2_9_21000_128",
      "stZeroKnowledge/ecmul_1-2_9_21000_96",
      "stZeroKnowledge/ecmul_1-2_9_28000_128",
      "stZeroKnowledge/ecmul_1-2_9_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_64",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_80",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_64",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_80",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_80",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_80",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_1_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_1_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_1_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_1_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_2_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_2_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_2_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_2_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_5616_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_5616_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_5616_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_5616_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_5617_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_5617_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_5617_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_5617_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_9935_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_9935_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_9935_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_9935_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_9_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_9_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_9_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_9_28000_96",
      "stZeroKnowledge/ecpairing_bad_length_191",
      "stZeroKnowledge/ecpairing_bad_length_193",
      "stZeroKnowledge/ecpairing_empty_data",
      "stZeroKnowledge/ecpairing_empty_data_insufficient_gas",
      "stZeroKnowledge/ecpairing_one_point_fail",
      "stZeroKnowledge/ecpairing_one_point_insufficient_gas",
      "stZeroKnowledge/ecpairing_one_point_not_in_subgroup",
      "stZeroKnowledge/ecpairing_one_point_with_g1_zero",
      "stZeroKnowledge/ecpairing_one_point_with_g2_zero",
      "stZeroKnowledge/ecpairing_one_point_with_g2_zero_and_g1_invalid",
      "stZeroKnowledge/ecpairing_perturb_g2_by_curve_order",
      "stZeroKnowledge/ecpairing_perturb_g2_by_field_modulus",
      "stZeroKnowledge/ecpairing_perturb_g2_by_field_modulus_again",
      "stZeroKnowledge/ecpairing_perturb_g2_by_one",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_curve_order",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_field_modulus",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_one",
      "stZeroKnowledge/ecpairing_three_point_fail_1",
      "stZeroKnowledge/ecpairing_three_point_match_1",
      "stZeroKnowledge/ecpairing_two_point_fail_1",
      "stZeroKnowledge/ecpairing_two_point_fail_2",
      "stZeroKnowledge/ecpairing_two_point_match_1",
      "stZeroKnowledge/ecpairing_two_point_match_2",
      "stZeroKnowledge/ecpairing_two_point_match_3",
      "stZeroKnowledge/ecpairing_two_point_match_4",
      "stZeroKnowledge/ecpairing_two_point_match_5",
      "stZeroKnowledge/ecpairing_two_point_oog",
      "stZeroKnowledge/ecpairing_two_points_with_one_g2_zero",
      "stZeroKnowledge/pairingTest",
      "stZeroKnowledge/pointMulAdd",
      "stZeroKnowledge/pointMulAdd2",
      "stZeroKnowledge2/ecmul_0-0_0_21000_0",
      "stZeroKnowledge2/ecmul_0-0_0_21000_128",
      "stZeroKnowledge2/ecmul_0-0_0_21000_40",
      "stZeroKnowledge2/ecmul_0-0_0_21000_64",
      "stZeroKnowledge2/ecmul_0-0_0_21000_80",
      "stZeroKnowledge2/ecmul_0-0_0_21000_96",
      "stZeroKnowledge2/ecmul_0-0_0_28000_0",
      "stZeroKnowledge2/ecmul_0-0_0_28000_128",
      "stZeroKnowledge2/ecmul_0-0_0_28000_40",
      "stZeroKnowledge2/ecmul_0-0_0_28000_64",
      "stZeroKnowledge2/ecmul_0-0_0_28000_80",
      "stZeroKnowledge2/ecmul_0-0_0_28000_96",
      "stZeroKnowledge2/ecmul_0-0_1_21000_128",
      "stZeroKnowledge2/ecmul_0-0_1_21000_96",
      "stZeroKnowledge2/ecmul_0-0_1_28000_128",
      "stZeroKnowledge2/ecmul_0-0_1_28000_96",
      "stZeroKnowledge2/ecmul_0-0_2_21000_128",
      "stZeroKnowledge2/ecmul_0-0_2_21000_96",
      "stZeroKnowledge2/ecmul_0-0_2_28000_128",
      "stZeroKnowledge2/ecmul_0-0_2_28000_96",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge2/ecmul_0-0_5616_21000_128",
      "stZeroKnowledge2/ecmul_0-0_5616_21000_96",
      "stZeroKnowledge2/ecmul_0-0_5616_28000_128",
      "stZeroKnowledge2/ecmul_0-0_5616_28000_96",
      "stZeroKnowledge2/ecmul_0-0_5617_21000_128",
      "stZeroKnowledge2/ecmul_0-0_5617_21000_96",
      "stZeroKnowledge2/ecmul_0-0_5617_28000_128",
      "stZeroKnowledge2/ecmul_0-0_5617_28000_96",
      "stZeroKnowledge2/ecmul_0-0_9935_21000_128",
      "stZeroKnowledge2/ecmul_0-0_9935_21000_96",
      "stZeroKnowledge2/ecmul_0-0_9935_28000_128",
      "stZeroKnowledge2/ecmul_0-0_9935_28000_96",
      "stZeroKnowledge2/ecmul_0-0_9_21000_128",
      "stZeroKnowledge2/ecmul_0-0_9_21000_96",
      "stZeroKnowledge2/ecmul_0-0_9_28000_128",
      "stZeroKnowledge2/ecmul_0-0_9_28000_96",
      "stZeroKnowledge2/ecmul_0-3_5616_28000_96",
      "stZeroKnowledge2/ecmul_1-2_0_21000_128",
      "stZeroKnowledge2/ecmul_1-2_0_21000_64",
      "stZeroKnowledge2/ecmul_1-2_0_21000_80",
      "stZeroKnowledge2/ecmul_1-2_0_21000_96",
      "stZeroKnowledge2/ecmul_1-2_0_28000_128",
      "stZeroKnowledge2/ecmul_1-2_0_28000_64",
      "stZeroKnowledge2/ecmul_1-2_0_28000_80",
      "stZeroKnowledge2/ecmul_1-2_0_28000_96",
      "stZeroKnowledge2/ecmul_1-2_1_21000_128",
      "stZeroKnowledge2/ecmul_1-2_1_21000_96",
      "stZeroKnowledge2/ecmul_1-2_1_28000_128",
      "stZeroKnowledge2/ecmul_1-2_1_28000_96",
      "stZeroKnowledge2/ecmul_1-2_2_21000_128",
      "stZeroKnowledge2/ecmul_1-2_2_21000_96"
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
    |> Enum.flat_map(fn test_path ->
      test_path
      |> read_state_test_file()
      |> Stream.filter(&fork_test?(&1, fork))
      |> Stream.flat_map(&run_test(&1, fork))
      |> Enum.filter(&failed_test?/1)
    end)
  end

  defp fork_test?({_test_name, test_data}, fork) do
    case Map.fetch(test_data["post"], fork) do
      {:ok, _test_data} -> true
      _ -> false
    end
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

  defp run_test({test_name, test}, hardfork) do
    hardfork_configuration = configuration(hardfork)

    test["post"][hardfork]
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      pre_state = account_interface(test).state

      indexes = post["indexes"]
      gas_limit_index = indexes["gas"]
      value_index = indexes["value"]
      data_index = indexes["data"]

      transaction =
        %Transaction{
          nonce: load_integer(test["transaction"]["nonce"]),
          gas_price: load_integer(test["transaction"]["gasPrice"]),
          gas_limit: load_integer(Enum.at(test["transaction"]["gasLimit"], gas_limit_index)),
          to: maybe_hex(test["transaction"]["to"]),
          value: load_integer(Enum.at(test["transaction"]["value"], value_index))
        }
        |> populate_init_or_data(maybe_hex(Enum.at(test["transaction"]["data"], data_index)))
        |> Transaction.Signature.sign_transaction(maybe_hex(test["transaction"]["secretKey"]))

      result =
        Transaction.execute_with_validation(
          pre_state,
          transaction,
          %Block.Header{
            beneficiary: maybe_hex(test["env"]["currentCoinbase"]),
            difficulty: load_integer(test["env"]["currentDifficulty"]),
            timestamp: load_integer(test["env"]["currentTimestamp"]),
            number: load_integer(test["env"]["currentNumber"]),
            gas_limit: load_integer(test["env"]["currentGasLimit"]),
            parent_hash: maybe_hex(test["env"]["previousHash"])
          },
          hardfork_configuration
        )

      {state, logs} =
        case result do
          {state, _, logs} -> {state, logs}
          _ -> {pre_state, []}
        end

      expected_hash =
        test["post"][hardfork]
        |> Enum.at(index)
        |> Map.fetch!("hash")
        |> maybe_hex()

      expected_logs = test["post"][hardfork] |> Enum.at(index) |> Map.fetch!("logs")
      logs_hash = logs_hash(logs)

      %{
        hardfork: hardfork,
        test_name: test_name,
        state_root_mismatch: state.root_hash != expected_hash,
        state_root_expected: expected_hash,
        state_root_actual: state.root_hash,
        logs_hash_mismatch: maybe_hex(expected_logs) != logs_hash,
        logs_hash_expected: maybe_hex(expected_logs),
        logs_hash_actual: logs_hash
      }
    end)
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

      _ ->
        nil
    end
  end

  defp populate_init_or_data(tx, data) do
    if Transaction.contract_creation?(tx) do
      %{tx | init: data}
    else
      %{tx | data: data}
    end
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

  def read_state_test_file(test_path) do
    test_path
    |> File.read!()
    |> Poison.decode!()
  end

  def account_interface(test) do
    db = MerklePatriciaTree.Test.random_ets_db()

    state = %Trie{
      db: db,
      root_hash: maybe_hex(test["env"]["previousHash"])
    }

    state =
      Enum.reduce(test["pre"], state, fn {address, account}, state ->
        storage = %Trie{
          root_hash: Trie.empty_trie_root_hash(),
          db: db
        }

        storage =
          Enum.reduce(account["storage"], storage, fn {key, value}, trie ->
            value = load_integer(value)

            if value == 0 do
              trie
            else
              Storage.put(trie.db, trie.root_hash, load_integer(key), value)
            end
          end)

        new_account = %Account{
          nonce: load_integer(account["nonce"]),
          balance: load_integer(account["balance"]),
          storage_root: storage.root_hash
        }

        state
        |> Account.put_account(maybe_hex(address), new_account)
        |> Account.put_code(maybe_hex(address), maybe_hex(account["code"]))
      end)

    AccountInterface.new(state)
  end

  defp logs_hash(logs) do
    logs
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  defp tests do
    ethereum_common_tests_path()
    |> Path.join("/GeneralStateTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
