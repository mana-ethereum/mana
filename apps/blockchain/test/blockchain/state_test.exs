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
      "stZeroKnowledge2/ecmul_1-2_2_21000_96",
      "stZeroKnowledge2/ecmul_1-2_2_21000_128",
      "stZeroKnowledge2/ecmul_1-2_1_28000_96",
      "stZeroKnowledge2/ecmul_1-2_1_28000_128",
      "stZeroKnowledge2/ecmul_1-2_1_21000_96",
      "stZeroKnowledge2/ecmul_1-2_1_21000_128",
      "stZeroKnowledge2/ecmul_1-2_0_28000_96",
      "stZeroKnowledge2/ecmul_1-2_0_28000_80",
      "stZeroKnowledge2/ecmul_1-2_0_28000_64",
      "stZeroKnowledge2/ecmul_1-2_0_28000_128",
      "stZeroKnowledge2/ecmul_1-2_0_21000_96",
      "stZeroKnowledge2/ecmul_1-2_0_21000_80",
      "stZeroKnowledge2/ecmul_1-2_0_21000_64",
      "stZeroKnowledge2/ecmul_1-2_0_21000_128",
      "stZeroKnowledge2/ecmul_0-3_9_28000_96",
      "stZeroKnowledge2/ecmul_0-3_9_28000_128",
      "stZeroKnowledge2/ecmul_0-3_9_21000_96",
      "stZeroKnowledge2/ecmul_0-3_9_21000_128",
      "stZeroKnowledge2/ecmul_0-3_9935_28000_96",
      "stZeroKnowledge2/ecmul_0-3_9935_28000_128",
      "stZeroKnowledge2/ecmul_0-3_9935_21000_96",
      "stZeroKnowledge2/ecmul_0-3_9935_21000_128",
      "stZeroKnowledge2/ecmul_0-3_5617_28000_96",
      "stZeroKnowledge2/ecmul_0-3_5617_28000_128",
      "stZeroKnowledge2/ecmul_0-3_5617_21000_96",
      "stZeroKnowledge2/ecmul_0-3_5617_21000_128",
      "stZeroKnowledge2/ecmul_0-3_5616_28000_96",
      "stZeroKnowledge2/ecmul_0-3_5616_28000_128",
      "stZeroKnowledge2/ecmul_0-3_5616_21000_96",
      "stZeroKnowledge2/ecmul_0-3_5616_21000_128",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge2/ecmul_0-3_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge2/ecmul_0-3_2_28000_96",
      "stZeroKnowledge2/ecmul_0-3_2_28000_128",
      "stZeroKnowledge2/ecmul_0-3_2_21000_96",
      "stZeroKnowledge2/ecmul_0-3_2_21000_128",
      "stZeroKnowledge2/ecmul_0-3_1_28000_96",
      "stZeroKnowledge2/ecmul_0-3_1_28000_128",
      "stZeroKnowledge2/ecmul_0-3_1_21000_96",
      "stZeroKnowledge2/ecmul_0-3_1_21000_128",
      "stZeroKnowledge2/ecmul_0-3_0_28000_96",
      "stZeroKnowledge2/ecmul_0-3_0_28000_80",
      "stZeroKnowledge2/ecmul_0-3_0_28000_64",
      "stZeroKnowledge2/ecmul_0-3_0_28000_128",
      "stZeroKnowledge2/ecmul_0-3_0_21000_96",
      "stZeroKnowledge2/ecmul_0-3_0_21000_80",
      "stZeroKnowledge2/ecmul_0-3_0_21000_64",
      "stZeroKnowledge2/ecmul_0-3_0_21000_128",
      "stZeroKnowledge2/ecmul_0-0_9_28000_96",
      "stZeroKnowledge2/ecmul_0-0_9_28000_128",
      "stZeroKnowledge2/ecmul_0-0_9_21000_96",
      "stZeroKnowledge2/ecmul_0-0_9_21000_128",
      "stZeroKnowledge2/ecmul_0-0_9935_28000_96",
      "stZeroKnowledge2/ecmul_0-0_9935_28000_128",
      "stZeroKnowledge2/ecmul_0-0_9935_21000_96",
      "stZeroKnowledge2/ecmul_0-0_9935_21000_128",
      "stZeroKnowledge2/ecmul_0-0_5617_28000_96",
      "stZeroKnowledge2/ecmul_0-0_5617_28000_128",
      "stZeroKnowledge2/ecmul_0-0_5617_21000_96",
      "stZeroKnowledge2/ecmul_0-0_5617_21000_128",
      "stZeroKnowledge2/ecmul_0-0_5616_28000_96",
      "stZeroKnowledge2/ecmul_0-0_5616_28000_128",
      "stZeroKnowledge2/ecmul_0-0_5616_21000_96",
      "stZeroKnowledge2/ecmul_0-0_5616_21000_128",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge2/ecmul_0-0_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge2/ecmul_0-0_2_28000_96",
      "stZeroKnowledge2/ecmul_0-0_2_28000_128",
      "stZeroKnowledge2/ecmul_0-0_2_21000_96",
      "stZeroKnowledge2/ecmul_0-0_2_21000_128",
      "stZeroKnowledge2/ecmul_0-0_1_28000_96",
      "stZeroKnowledge2/ecmul_0-0_1_28000_128",
      "stZeroKnowledge2/ecmul_0-0_1_21000_96",
      "stZeroKnowledge2/ecmul_0-0_1_21000_128",
      "stZeroKnowledge2/ecmul_0-0_0_28000_96",
      "stZeroKnowledge2/ecmul_0-0_0_28000_80",
      "stZeroKnowledge2/ecmul_0-0_0_28000_64",
      "stZeroKnowledge2/ecmul_0-0_0_28000_40",
      "stZeroKnowledge2/ecmul_0-0_0_28000_128",
      "stZeroKnowledge2/ecmul_0-0_0_28000_0",
      "stZeroKnowledge2/ecmul_0-0_0_21000_96",
      "stZeroKnowledge2/ecmul_0-0_0_21000_80",
      "stZeroKnowledge2/ecmul_0-0_0_21000_64",
      "stZeroKnowledge2/ecmul_0-0_0_21000_40",
      "stZeroKnowledge2/ecmul_0-0_0_21000_128",
      "stZeroKnowledge2/ecmul_0-0_0_21000_0",
      "stZeroKnowledge2/ecadd_6-9_19274124-124124_25000_128",
      "stZeroKnowledge2/ecadd_6-9_19274124-124124_21000_128",
      "stZeroKnowledge2/ecadd_1145-3932_2969-1336_25000_128",
      "stZeroKnowledge2/ecadd_1145-3932_2969-1336_21000_128",
      "stZeroKnowledge2/ecadd_1145-3932_1145-4651_25000_192",
      "stZeroKnowledge2/ecadd_1145-3932_1145-4651_21000_192",
      "stZeroKnowledge2/ecadd_1-3_0-0_25000_80",
      "stZeroKnowledge2/ecadd_1-3_0-0_21000_80",
      "stZeroKnowledge2/ecadd_1-2_1-2_25000_192",
      "stZeroKnowledge2/ecadd_1-2_1-2_25000_128",
      "stZeroKnowledge2/ecadd_1-2_1-2_21000_192",
      "stZeroKnowledge2/ecadd_1-2_1-2_21000_128",
      "stZeroKnowledge2/ecadd_1-2_0-0_25000_64",
      "stZeroKnowledge2/ecadd_1-2_0-0_25000_192",
      "stZeroKnowledge2/ecadd_1-2_0-0_25000_128",
      "stZeroKnowledge2/ecadd_1-2_0-0_21000_64",
      "stZeroKnowledge2/ecadd_1-2_0-0_21000_192",
      "stZeroKnowledge2/ecadd_1-2_0-0_21000_128",
      "stZeroKnowledge2/ecadd_0-3_1-2_25000_128",
      "stZeroKnowledge2/ecadd_0-3_1-2_21000_128",
      "stZeroKnowledge2/ecadd_0-0_1-3_25000_128",
      "stZeroKnowledge2/ecadd_0-0_1-3_21000_128",
      "stZeroKnowledge2/ecadd_0-0_1-2_25000_192",
      "stZeroKnowledge2/ecadd_0-0_1-2_25000_128",
      "stZeroKnowledge2/ecadd_0-0_1-2_21000_192",
      "stZeroKnowledge2/ecadd_0-0_1-2_21000_128",
      "stZeroKnowledge2/ecadd_0-0_0-0_25000_80",
      "stZeroKnowledge2/ecadd_0-0_0-0_25000_64",
      "stZeroKnowledge2/ecadd_0-0_0-0_25000_192",
      "stZeroKnowledge2/ecadd_0-0_0-0_25000_128",
      "stZeroKnowledge2/ecadd_0-0_0-0_25000_0",
      "stZeroKnowledge2/ecadd_0-0_0-0_21000_80",
      "stZeroKnowledge2/ecadd_0-0_0-0_21000_64",
      "stZeroKnowledge2/ecadd_0-0_0-0_21000_192",
      "stZeroKnowledge2/ecadd_0-0_0-0_21000_128",
      "stZeroKnowledge2/ecadd_0-0_0-0_21000_0",
      "stZeroKnowledge/pointMulAdd2",
      "stZeroKnowledge/pointMulAdd",
      "stZeroKnowledge/pointAddTrunc",
      "stZeroKnowledge/pointAdd",
      "stZeroKnowledge/pairingTest",
      "stZeroKnowledge/ecpairing_two_points_with_one_g2_zero",
      "stZeroKnowledge/ecpairing_two_point_oog",
      "stZeroKnowledge/ecpairing_two_point_match_5",
      "stZeroKnowledge/ecpairing_two_point_match_4",
      "stZeroKnowledge/ecpairing_two_point_match_3",
      "stZeroKnowledge/ecpairing_two_point_match_2",
      "stZeroKnowledge/ecpairing_two_point_match_1",
      "stZeroKnowledge/ecpairing_two_point_fail_2",
      "stZeroKnowledge/ecpairing_two_point_fail_1",
      "stZeroKnowledge/ecpairing_three_point_match_1",
      "stZeroKnowledge/ecpairing_three_point_fail_1",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_one",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_field_modulus",
      "stZeroKnowledge/ecpairing_perturb_zeropoint_by_curve_order",
      "stZeroKnowledge/ecpairing_perturb_g2_by_one",
      "stZeroKnowledge/ecpairing_perturb_g2_by_field_modulus_again",
      "stZeroKnowledge/ecpairing_perturb_g2_by_field_modulus",
      "stZeroKnowledge/ecpairing_perturb_g2_by_curve_order",
      "stZeroKnowledge/ecpairing_one_point_with_g2_zero_and_g1_invalid",
      "stZeroKnowledge/ecpairing_one_point_with_g2_zero",
      "stZeroKnowledge/ecpairing_one_point_with_g1_zero",
      "stZeroKnowledge/ecpairing_one_point_not_in_subgroup",
      "stZeroKnowledge/ecpairing_one_point_insufficient_gas",
      "stZeroKnowledge/ecpairing_one_point_fail",
      "stZeroKnowledge/ecpairing_empty_data_insufficient_gas",
      "stZeroKnowledge/ecpairing_empty_data",
      "stZeroKnowledge/ecpairing_bad_length_193",
      "stZeroKnowledge/ecpairing_bad_length_191",
      "stZeroKnowledge/ecmul_7827-6598_9_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_9_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_9_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_9_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_9935_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_9935_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_9935_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_9935_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_5617_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_5617_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_5617_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_5617_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_5616_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_5616_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_5616_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_5616_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_2_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_2_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_2_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_2_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_1_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_1_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_1_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_1_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_80",
      "stZeroKnowledge/ecmul_7827-6598_1456_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_80",
      "stZeroKnowledge/ecmul_7827-6598_1456_21000_128",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_96",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_80",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_64",
      "stZeroKnowledge/ecmul_7827-6598_0_28000_128",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_96",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_80",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_64",
      "stZeroKnowledge/ecmul_7827-6598_0_21000_128",
      "stZeroKnowledge/ecmul_1-3_9_28000_96",
      "stZeroKnowledge/ecmul_1-3_9_28000_128",
      "stZeroKnowledge/ecmul_1-3_9_21000_96",
      "stZeroKnowledge/ecmul_1-3_9_21000_128",
      "stZeroKnowledge/ecmul_1-3_9935_28000_96",
      "stZeroKnowledge/ecmul_1-3_9935_28000_128",
      "stZeroKnowledge/ecmul_1-3_9935_21000_96",
      "stZeroKnowledge/ecmul_1-3_9935_21000_128",
      "stZeroKnowledge/ecmul_1-3_5617_28000_96",
      "stZeroKnowledge/ecmul_1-3_5617_28000_128",
      "stZeroKnowledge/ecmul_1-3_5617_21000_96",
      "stZeroKnowledge/ecmul_1-3_5617_21000_128",
      "stZeroKnowledge/ecmul_1-3_5616_28000_96",
      "stZeroKnowledge/ecmul_1-3_5616_28000_128",
      "stZeroKnowledge/ecmul_1-3_5616_21000_96",
      "stZeroKnowledge/ecmul_1-3_5616_21000_128",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge/ecmul_1-3_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge/ecmul_1-3_2_28000_96",
      "stZeroKnowledge/ecmul_1-3_2_28000_128",
      "stZeroKnowledge/ecmul_1-3_2_21000_96",
      "stZeroKnowledge/ecmul_1-3_2_21000_128",
      "stZeroKnowledge/ecmul_1-3_1_28000_96",
      "stZeroKnowledge/ecmul_1-3_1_28000_128",
      "stZeroKnowledge/ecmul_1-3_1_21000_96",
      "stZeroKnowledge/ecmul_1-3_1_21000_128",
      "stZeroKnowledge/ecmul_1-3_0_28000_96",
      "stZeroKnowledge/ecmul_1-3_0_28000_80",
      "stZeroKnowledge/ecmul_1-3_0_28000_64",
      "stZeroKnowledge/ecmul_1-3_0_28000_128",
      "stZeroKnowledge/ecmul_1-3_0_21000_96",
      "stZeroKnowledge/ecmul_1-3_0_21000_80",
      "stZeroKnowledge/ecmul_1-3_0_21000_64",
      "stZeroKnowledge/ecmul_1-3_0_21000_128",
      "stZeroKnowledge/ecmul_1-2_9_28000_96",
      "stZeroKnowledge/ecmul_1-2_9_28000_128",
      "stZeroKnowledge/ecmul_1-2_9_21000_96",
      "stZeroKnowledge/ecmul_1-2_9_21000_128",
      "stZeroKnowledge/ecmul_1-2_9935_28000_96",
      "stZeroKnowledge/ecmul_1-2_9935_28000_128",
      "stZeroKnowledge/ecmul_1-2_9935_21000_96",
      "stZeroKnowledge/ecmul_1-2_9935_21000_128",
      "stZeroKnowledge/ecmul_1-2_616_28000_96",
      "stZeroKnowledge/ecmul_1-2_5617_28000_96",
      "stZeroKnowledge/ecmul_1-2_5617_28000_128",
      "stZeroKnowledge/ecmul_1-2_5617_21000_96",
      "stZeroKnowledge/ecmul_1-2_5617_21000_128",
      "stZeroKnowledge/ecmul_1-2_5616_28000_128",
      "stZeroKnowledge/ecmul_1-2_5616_21000_96",
      "stZeroKnowledge/ecmul_1-2_5616_21000_128",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_96",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_80",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_28000_128",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_96",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_80",
      "stZeroKnowledge/ecmul_1-2_340282366920938463463374607431768211456_21000_128",
      "stZeroKnowledge/ecmul_1-2_2_28000_96",
      "stZeroKnowledge/ecmul_1-2_2_28000_128",
      "stTransactionTest/Opcodes_TransactionInit",
      "stTransactionTest/EmptyTransaction2",
      "stStaticCall/static_callWithHighValueAndOOGatTxLevel",
      "stStaticCall/static_RevertOpcodeCalls",
      "stStaticCall/static_PostToReturn1",
      "stStaticCall/static_CallEcrecover0_0input",
      "stStaticCall/static_Call1024PreCalls2",
      "stSpecialTest/failed_tx_xcf416c53",
      "stRevertTest/RevertPrefound",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stRevertTest/RevertOpcodeReturn",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeInInit",
      "stRevertTest/RevertOpcodeInCreateReturns",
      "stRevertTest/RevertOpcodeInCallsOnNonEmptyReturnData",
      "stRevertTest/RevertOpcodeDirectCall",
      "stRevertTest/RevertOpcodeCreate",
      "stRevertTest/RevertOpcodeCalls",
      "stRevertTest/RevertOpcode",
      "stRevertTest/RevertInStaticCall",
      "stRevertTest/RevertInDelegateCall",
      "stRevertTest/RevertInCreateInInit",
      "stRevertTest/RevertInCallCode",
      "stRevertTest/PythonRevertTestTue201814-1430",
      "stReturnDataTest/returndatasize_initial_zero_read",
      "stReturnDataTest/returndatasize_initial",
      "stReturnDataTest/returndatasize_following_successful_create",
      "stReturnDataTest/returndatasize_bug",
      "stReturnDataTest/returndatasize_after_successful_staticcall",
      "stReturnDataTest/returndatasize_after_successful_delegatecall",
      "stReturnDataTest/returndatasize_after_successful_callcode",
      "stReturnDataTest/returndatasize_after_oog_after_deeper",
      "stReturnDataTest/returndatasize_after_failing_staticcall",
      "stReturnDataTest/returndatasize_after_failing_delegatecall",
      "stReturnDataTest/returndatasize_after_failing_callcode",
      "stReturnDataTest/returndatacopy_following_revert_in_create",
      "stReturnDataTest/returndatacopy_following_revert",
      "stReturnDataTest/returndatacopy_following_call",
      "stReturnDataTest/returndatacopy_after_successful_staticcall",
      "stReturnDataTest/returndatacopy_after_successful_delegatecall",
      "stReturnDataTest/returndatacopy_after_successful_callcode",
      "stReturnDataTest/returndatacopy_after_revert_in_staticcall",
      "stReturnDataTest/returndatacopy_afterFailing_create",
      "stReturnDataTest/returndatacopy_0_0_following_successful_create",
      "stReturnDataTest/modexp_modsize0_returndatasize",
      "stReturnDataTest/create_callprecompile_returndatasize",
      "stReturnDataTest/call_then_create_successful_then_returndatasize",
      "stReturnDataTest/call_then_call_value_fail_then_returndatasize",
      "stReturnDataTest/call_outsize_then_create_successful_then_returndatasize",
      "stReturnDataTest/call_ecrec_success_empty_then_returndatasize",
      "stRandom2/randomStatetest642",
      "stPreCompiledContracts2/modexpRandomInput",
      "stPreCompiledContracts/modexp_9_3711_37111_25000",
      "stPreCompiledContracts/modexp_9_37111_37111_35000",
      "stPreCompiledContracts/modexp_9_37111_37111_22000",
      "stPreCompiledContracts/modexp_9_37111_37111_20500",
      "stPreCompiledContracts/modexp_9_37111_37111_155000",
      "stPreCompiledContracts/modexp_9_37111_37111_1000000",
      "stPreCompiledContracts/modexp_55190_55190_42965_35000",
      "stPreCompiledContracts/modexp_55190_55190_42965_25000",
      "stPreCompiledContracts/modexp_55190_55190_42965_22000",
      "stPreCompiledContracts/modexp_55190_55190_42965_20500",
      "stPreCompiledContracts/modexp_55190_55190_42965_155000",
      "stPreCompiledContracts/modexp_55190_55190_42965_1000000",
      "stPreCompiledContracts/modexp_49_2401_2401_35000",
      "stPreCompiledContracts/modexp_49_2401_2401_25000",
      "stPreCompiledContracts/modexp_49_2401_2401_22000",
      "stPreCompiledContracts/modexp_49_2401_2401_20500",
      "stPreCompiledContracts/modexp_49_2401_2401_155000",
      "stPreCompiledContracts/modexp_49_2401_2401_1000000",
      "stPreCompiledContracts/modexp_3_5_100_35000",
      "stPreCompiledContracts/modexp_3_5_100_25000",
      "stPreCompiledContracts/modexp_3_5_100_22000",
      "stPreCompiledContracts/modexp_3_5_100_20500",
      "stPreCompiledContracts/modexp_3_5_100_155000",
      "stPreCompiledContracts/modexp_3_5_100_1000000",
      "stPreCompiledContracts/modexp_3_28948_11579_20500",
      "stPreCompiledContracts/modexp_3_09984_39936_35000",
      "stPreCompiledContracts/modexp_3_09984_39936_25000",
      "stPreCompiledContracts/modexp_3_09984_39936_22000",
      "stPreCompiledContracts/modexp_3_09984_39936_155000",
      "stPreCompiledContracts/modexp_3_09984_39936_1000000",
      "stPreCompiledContracts/modexp_39936_1_55201_35000",
      "stPreCompiledContracts/modexp_39936_1_55201_25000",
      "stPreCompiledContracts/modexp_39936_1_55201_22000",
      "stPreCompiledContracts/modexp_39936_1_55201_20500",
      "stPreCompiledContracts/modexp_39936_1_55201_155000",
      "stPreCompiledContracts/modexp_39936_1_55201_1000000",
      "stPreCompiledContracts/modexp_37120_37111_97_35000",
      "stPreCompiledContracts/modexp_37120_37111_97_25000",
      "stPreCompiledContracts/modexp_37120_37111_97_22000",
      "stPreCompiledContracts/modexp_37120_37111_97_20500",
      "stPreCompiledContracts/modexp_37120_37111_97_155000",
      "stPreCompiledContracts/modexp_37120_37111_97_1000000",
      "stPreCompiledContracts/modexp_37120_37111_37111_35000",
      "stPreCompiledContracts/modexp_37120_37111_37111_25000",
      "stPreCompiledContracts/modexp_37120_37111_37111_22000",
      "stPreCompiledContracts/modexp_37120_37111_37111_20500",
      "stPreCompiledContracts/modexp_37120_37111_37111_155000",
      "stPreCompiledContracts/modexp_37120_37111_37111_1000000",
      "stPreCompiledContracts/modexp_37120_37111_1_35000",
      "stPreCompiledContracts/modexp_37120_37111_1_25000",
      "stPreCompiledContracts/modexp_37120_37111_1_20500",
      "stPreCompiledContracts/modexp_37120_37111_1_155000",
      "stPreCompiledContracts/modexp_37120_37111_1_1000000",
      "stPreCompiledContracts/modexp_37120_37111_0_35000",
      "stPreCompiledContracts/modexp_37120_37111_0_25000",
      "stPreCompiledContracts/modexp_37120_37111_0_22000",
      "stPreCompiledContracts/modexp_37120_37111_0_20500",
      "stPreCompiledContracts/modexp_37120_37111_0_155000",
      "stPreCompiledContracts/modexp_37120_37111_0_1000000",
      "stPreCompiledContracts/modexp_37120_22411_22000",
      "stPreCompiledContracts/modexp",
      "stPreCompiledContracts/identity_to_smaller",
      "stPreCompiledContracts/identity_to_bigger",
      "stCreateTest/CreateOOGafterInitCodeReturndataSize",
      "stCreateTest/CreateOOGafterInitCodeReturndata2"
    ],
    "EIP150" => [
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasBefore",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAt",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAfter",
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/CreateTransactionReverted",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeInInit",
      "stRandom2/201503110226PYTHON_DUP6",
      "stInitCodeTest/OutOfGasPrefundedContractCreation",
      "stInitCodeTest/OutOfGasContractCreation",
      "stInitCodeTest/NotEnoughCashContractCreation"
    ],
    "EIP158" => [
      "stTransactionTest/EmptyTransaction2",
      "stSpecialTest/failed_tx_xcf416c53",
      "stRevertTest/RevertPrefound",
      "stRevertTest/RevertOpcodeMultipleSubCalls"
    ],
    "Frontier" => [
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/CreateTransactionReverted",
      "stRandom2/201503110226PYTHON_DUP6",
      "stInitCodeTest/NotEnoughCashContractCreation",
      "stCallCreateCallCodeTest/createNameRegistratorPerTxsNotEnoughGas"
    ],
    "Homestead" => [
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasBefore",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAt",
      "stTransitionTest/createNameRegistratorPerTxsNotEnoughGasAfter",
      "stTransactionTest/UserTransactionGasLimitIsTooLowWhenZeroCost",
      "stTransactionTest/TransactionToItselfNotEnoughFounds",
      "stTransactionTest/TransactionNonceCheck2",
      "stTransactionTest/TransactionNonceCheck",
      "stTransactionTest/RefundOverflow2",
      "stTransactionTest/RefundOverflow",
      "stTransactionTest/OverflowGasRequire",
      "stTransactionTest/EmptyTransaction",
      "stTransactionTest/CreateTransactionReverted",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeInInit",
      "stRandom2/201503110226PYTHON_DUP6",
      "stRandom/randomStatetest347",
      "stRandom/randomStatetest184",
      "stInitCodeTest/OutOfGasPrefundedContractCreation",
      "stInitCodeTest/OutOfGasContractCreation",
      "stInitCodeTest/NotEnoughCashContractCreation",
      "stDelegatecallTestHomestead/callcodeOutput3partialFail",
      "stDelegatecallTestHomestead/callcodeOutput3partial",
      "stDelegatecallTestHomestead/callcodeOutput3Fail",
      "stDelegatecallTestHomestead/callcodeOutput3",
      "stDelegatecallTestHomestead/callcodeOutput2",
      "stDelegatecallTestHomestead/callcodeOutput1",
      "stDelegatecallTestHomestead/callOutput3partialFail",
      "stDelegatecallTestHomestead/callOutput3partial",
      "stDelegatecallTestHomestead/callOutput3Fail",
      "stDelegatecallTestHomestead/callOutput3",
      "stDelegatecallTestHomestead/callOutput2",
      "stDelegatecallTestHomestead/callOutput1"
    ]
  }

  test "Blockchain state tests" do
    Enum.each(test_directories(), fn directory_path ->
      test_group = Enum.fetch!(String.split(directory_path, "/"), 4)

      directory_path
      |> tests()
      |> Enum.each(fn test_path ->
        test_path
        |> read_state_test_file()
        |> Enum.each(fn {test_name, test} ->
          run_test(test_group, test_name, test)
        end)
      end)
    end)
  end

  defp run_test(test_group, test_name, test) do
    test["post"]
    |> Enum.each(fn {hardfork, _test_data} ->
      failing_tests = Map.get(@failing_tests, hardfork, %{})

      if !Enum.member?(failing_tests, "#{test_group}/#{test_name}") do
        hardfork_configuration = configuration(hardfork)

        if hardfork_configuration do
          run_transaction(test_name, test, hardfork, hardfork_configuration)
        end
      end
    end)
  end

  defp run_transaction(test_name, test, hardfork, hardfork_configuration) do
    test["post"][hardfork]
    |> Enum.with_index()
    |> Enum.each(fn {post, index} ->
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

      assert state.root_hash == expected_hash,
             "State root mismatch for #{test_name} on #{hardfork}"

      expected_logs = test["post"][hardfork] |> Enum.at(index) |> Map.fetch!("logs")
      logs_hash = logs_hash(logs)

      assert maybe_hex(expected_logs) == logs_hash,
             "Logs hash mismatch for #{test_name} on #{hardfork}"
    end)
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

  def state_test_file_name(group, test) do
    file_name = Path.join(~w(st#{group} #{test}.json))
    relative_path = Path.join(~w(.. .. ethereum_common_tests GeneralStateTests #{file_name}))

    System.cwd()
    |> Path.join(relative_path)
    |> Path.expand()
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

  defp test_directories do
    path = Path.join([EthCommonTest.Helpers.ethereum_common_tests_path(), "GeneralStateTests"])
    wildcard = path <> "/*"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp tests(directory_path) do
    wildcard = directory_path <> "/**/*.json"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end
end
