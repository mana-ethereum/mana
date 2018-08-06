defmodule BlockchainTest do
  use ExUnit.Case
  use EthCommonTest.Harness

  alias Blockchain.{Blocktree, Account, Transaction, Chain}
  alias MerklePatriciaTree.Trie
  alias Blockchain.Account.Storage
  alias Block.Header

  doctest Blockchain

  @ethereum_common_tests_path System.cwd() <> "/../../ethereum_common_tests/BlockchainTests/"

  @failing_tests %{
    "Frontier" => [
      "GeneralStateTests/stMemoryTest/extcodecopy_dejavu_d0g0v0.json",
      "bcRandomBlockhashTest/randomStatetest21BC.json"
    ],
    "Homestead" => [
      "GeneralStateTests/stAttackTest/CrashingTransaction_d0g0v0.json",
      "GeneralStateTests/stBadOpcode/badOpcodes_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcallcode_001_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcallcode_001_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcallcode_001_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcodecall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcallcodecallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcall_100_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcallcode_101_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcodecall_110_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcodecall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcodecallcode_111_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesCallCodeHomestead/callcodecallcodecallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcallcode_001_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcallcode_001_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcallcode_001_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcallcode_001_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcode_01_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcode_01_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcode_01_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_010_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_010_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_010_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_010_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_010_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_011_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_011_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_011_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_011_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_011_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcallcodecallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecall_10_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecall_10_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecall_10_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_100_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_101_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcode_11_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcode_11_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcode_11_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_110_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecall_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_OOGE_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_OOGMAfter_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_OOGMBefore_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_SuicideEnd_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_SuicideMiddle_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_111_d0g0v0.json",
      "GeneralStateTests/stCallDelegateCodesHomestead/callcodecallcodecallcode_ABCB_RECURSIVE_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcallcallcode_001_OOGMAfter_1_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcallcallcode_001_OOGMAfter_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcall_100_OOGMAfter_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcallcode_101_OOGMAfter_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcallcode_101_OOGMAfter_3_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcodecall_110_OOGMAfter_1_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcodecall_110_OOGMAfter_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcodecallcode_111_OOGMAfter_1_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcodecallcode_111_OOGMAfter_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcodecallcodecallcode_111_OOGMAfter_3_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/contractCreationMakeCallThatAskMoreGasThenTransactionProvided_d0g0v0.json",
      "GeneralStateTests/stCodeSizeLimit/codesizeOOGInvalidSize_d0g0v0.json",
      "GeneralStateTests/stCodeSizeLimit/codesizeValid_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSSTOREDuringInit_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_ThenStoreThenReturn_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_WithValueToItself_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_WithValue_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateEContractInInit_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateNEContractInInitOOG_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateNEContractInInit_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_empty000CreateinInitCode_Transaction_d0g0v0.json",
      "GeneralStateTests/stCreateTest/TransactionCollisionToEmpty_d0g0v0.json",
      "GeneralStateTests/stCreateTest/TransactionCollisionToEmpty_d0g0v1.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Call1024BalanceTooLow_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Call1024OOG_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Call1024PreCalls_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/CallLoseGasOOG_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/CallRecursiveBombPreCall_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/CallcodeLoseGasOOG_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Delegatecall1024OOG_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Delegatecall1024_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput1_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput2_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput3Fail_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput3_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput3partialFail_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/callOutput3partial_d0g1v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/deleagateCallAfterValueTransfer_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallBasic_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallEmptycontract_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallInInitcodeToEmptyContract_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallInInitcodeToExistingContract_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallOOGinCall_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallSenderCheck_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallValueCheck_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode2SelfCall_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/NewGasPriceForCodes_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawDelegateCallGasMemory_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawDelegateCallGas_d0g0v0.json",
      "GeneralStateTests/stHomesteadSpecific/contractCreationOOGdontLeaveEmptyContractViaTransaction_d0g0v0.json",
      "GeneralStateTests/stHomesteadSpecific/createContractViaTransactionCost53000_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/TransactionCreateAutoSuicideContract_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/TransactionCreateStopInInitcode_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/NewGasPriceForCodesWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemoryTest/extcodecopy_dejavu_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_DELEGATECALL_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_DELEGATECALL_ToNonNonZeroBalance_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_DELEGATECALL_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_DELEGATECALL_d0g0v0.json",
      "GeneralStateTests/stRandom2/randomStatetest571_d0g0v0.json",
      "GeneralStateTests/stRandom2/randomStatetest643_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/StackDepthLimitSEC_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/deploymentError_d0g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d0g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d10g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d11g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d12g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d13g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d14g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d15g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d1g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d2g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d3g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d4g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d5g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d6g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d7g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d8g0v0.json",
      "GeneralStateTests/stStackTests/stackOverflowM1DUP_d9g0v0.json",
      "GeneralStateTests/stTransactionTest/CreateTransactionSuccess_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/EmptyTransaction2_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/EmptyTransaction3_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d100g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d101g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d102g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d103g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d104g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d105g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d106g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d107g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d108g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d109g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d10g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d110g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d111g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d112g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d113g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d114g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d115g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d116g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d117g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d118g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d119g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d11g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d120g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d121g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d122g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d123g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d124g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d12g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d13g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d14g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d15g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d16g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d17g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d18g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d19g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d1g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d20g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d21g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d22g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d23g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d24g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d25g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d26g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d27g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d28g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d29g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d2g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d30g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d31g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d32g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d34g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d35g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d36g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d39g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d3g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d40g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d41g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d42g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d43g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d44g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d45g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d46g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d47g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d48g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d49g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d4g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d50g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d51g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d52g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d53g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d54g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d55g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d56g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d57g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d58g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d59g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d5g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d60g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d61g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d62g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d63g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d64g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d65g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d66g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d67g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d68g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d69g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d6g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d70g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d71g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d72g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d73g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d74g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d75g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d76g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d77g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d78g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d79g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d7g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d80g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d81g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d82g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d83g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d84g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d85g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d86g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d87g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d88g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d89g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d8g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d90g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d91g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d92g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d93g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d94g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d95g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d96g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d97g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d98g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d99g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d9g0v0.json",
      "GeneralStateTests/stTransactionTest/TransactionSendingToEmpty_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsAfter_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsAt_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsBefore_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/delegatecallAfterTransition_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/delegatecallAtTransition_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/delegatecallBeforeTransition_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstructionPartial_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstruction_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstruction_d0g1v0.json",
      "GeneralStateTests/stWalletTest/multiOwnedConstructionCorrect_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstructionPartial_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstruction_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstruction_d0g1v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_DELEGATECALL_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_DELEGATECALL_ToNonZeroBalance_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_DELEGATECALL_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_DELEGATECALL_d0g0v0.json",
      "bcExploitTest/DelegateCallSpam.json",
      "bcExploitTest/ShanghaiLove.json",
      "bcExploitTest/StrangeContractCreation.json",
      "bcForkStressTest/ForkStressTest.json",
      "bcGasPricerTest/RPC_API_Test.json",
      "bcMultiChainTest/CallContractFromNotBestBlock.json",
      "bcMultiChainTest/UncleFromSideChain.json",
      "bcRandomBlockhashTest/randomStatetest21BC.json",
      "bcTotalDifficultyTest/lotsOfBranchesOverrideAtTheMiddle.json",
      "bcTotalDifficultyTest/lotsOfLeafs.json",
      "bcTotalDifficultyTest/newChainFrom4Block.json",
      "bcTotalDifficultyTest/newChainFrom5Block.json",
      "bcTotalDifficultyTest/newChainFrom6Block.json",
      "bcTotalDifficultyTest/sideChainWithNewMaxDifficultyStartingFromBlock3AfterBlock4.json",
      "bcUncleHeaderValidity/diffTooLow2.json",
      "bcUncleHeaderValidity/futureUncleTimestampDifficultyDrop.json",
      "bcUncleHeaderValidity/futureUncleTimestampDifficultyDrop2.json",
      "bcUncleHeaderValidity/gasLimitTooHigh.json",
      "bcUncleHeaderValidity/gasLimitTooHighExactBound.json",
      "bcUncleHeaderValidity/gasLimitTooLow.json",
      "bcUncleHeaderValidity/gasLimitTooLowExactBound.json",
      "bcUncleHeaderValidity/nonceWrong.json",
      "bcUncleHeaderValidity/timestampTooHigh.json",
      "bcUncleHeaderValidity/timestampTooLow.json",
      "bcUncleHeaderValidity/wrongMixHash.json",
      "bcUncleHeaderValidity/wrongParentHash.json",
      "bcUncleHeaderValidity/wrongStateRoot.json",
      "bcUncleTest/UncleIsBrother.json",
      "bcValidBlockTest/RecallSuicidedContract.json",
      "bcValidBlockTest/RecallSuicidedContractInOneBlock.json",
      "bcValidBlockTest/dataTx2.json",
      "bcValidBlockTest/timeDiff0.json",
      "bcValidBlockTest/timeDiff12.json",
      "bcValidBlockTest/timeDiff13.json",
      "bcValidBlockTest/timeDiff14.json",
      "bcWalletTest/wallet2outOf3txs.json",
      "bcWalletTest/wallet2outOf3txs2.json",
      "bcWalletTest/wallet2outOf3txsRevoke.json",
      "bcWalletTest/wallet2outOf3txsRevokeAndConfirmAgain.json",
      "bcWalletTest/walletReorganizeOwners.json"
    ],
    # the rest are not implemented yet
    "Byzantium" => [],
    "EIP150" => [],
    "EIP158" => [],
    "Constantinople" => [],
    "EIP158ToByzantiumAt5" => [],
    "FrontierToHomesteadAt5" => [],
    "HomesteadToDaoAt5" => [],
    "HomesteadToEIP150At5" => []
  }

  test "runs blockchain tests" do
    Enum.each(tests(), fn json_test_path ->
      json_test_path
      |> read_test()
      |> Enum.map(fn {_name, test} -> test end)
      |> Enum.each(fn test ->
        if !failing_test?(json_test_path, test) do
          run_test(test)
        end
      end)
    end)
  end

  defp failing_test?(json_test_path, json_test) do
    hardfork_failing_tests = Map.fetch!(@failing_tests, json_test["network"])

    Enum.any?(hardfork_failing_tests, fn failing_test ->
      String.contains?(json_test_path, failing_test)
    end)
  end

  defp read_test(path) do
    path
    |> File.read!()
    |> Poison.decode!()
  end

  defp run_test(json_test) do
    chain = load_chain(json_test["network"])

    if chain do
      state = populate_prestate(json_test)

      blocktree =
        create_blocktree()
        |> add_genesis_block(json_test, state, chain)
        |> add_blocks(json_test, state, chain)

      best_block_hash = maybe_hex(json_test["lastblockhash"])

      assert blocktree.best_block.block_hash == best_block_hash
    end
  end

  defp load_chain(hardfork) do
    config = evm_config(hardfork)

    case hardfork do
      "Frontier" ->
        Chain.load_chain(:frontier_test, config)

      "Homestead" ->
        Chain.load_chain(:homestead_test, config)

      _ ->
        nil
    end
  end

  defp evm_config(hardfork) do
    case hardfork do
      "Frontier" ->
        EVM.Configuration.Frontier.new()

      "Homestead" ->
        EVM.Configuration.Homestead.new()

      _ ->
        nil
    end
  end

  defp add_genesis_block(blocktree, json_test, state, chain) do
    block =
      if json_test["genesisRLP"] do
        {:ok, block} = Blockchain.Block.decode_rlp(json_test["genesisRLP"])

        block
      end

    genesis_block = block_from_json(block, json_test["genesisBlockHeader"])

    {:ok, blocktree} =
      Blocktree.verify_and_add_block(
        blocktree,
        chain,
        genesis_block,
        state.db,
        false,
        maybe_hex(json_test["genesisBlockHeader"]["hash"])
      )

    blocktree
  end

  defp create_blocktree do
    Blocktree.new_tree()
  end

  defp add_blocks(blocktree, json_test, state, chain) do
    Enum.reduce(json_test["blocks"], blocktree, fn json_block, acc ->
      block = json_block["rlp"] |> Blockchain.Block.decode_rlp()

      case block do
        {:ok, block} ->
          block =
            block_from_json(
              block,
              json_block["blockHeader"],
              json_block["transactions"],
              json_block["uncleHeaders"]
            )

          case Blocktree.verify_and_add_block(acc, chain, block, state.db) do
            {:ok, blocktree} -> blocktree
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp block_from_json(block, json_header, json_transactions \\ [], json_ommers \\ []) do
    block = block || %Blockchain.Block{}
    header = header_from_json(json_header)
    transactions = transactions_from_json(json_transactions)
    ommers = ommers_from_json(json_ommers)

    %{block | header: header, transactions: transactions, ommers: ommers}
  end

  defp header_from_json(json_header) do
    %Header{
      parent_hash: maybe_hex(json_header["parentHash"]),
      ommers_hash: maybe_hex(json_header["uncleHash"]),
      beneficiary: maybe_hex(json_header["coinbase"]),
      state_root: maybe_hex(json_header["stateRoot"]),
      transactions_root: maybe_hex(json_header["transactionsTrie"]),
      receipts_root: maybe_hex(json_header["receiptTrie"]),
      logs_bloom: maybe_hex(json_header["bloom"]),
      difficulty: load_integer(json_header["difficulty"]),
      number: load_integer(json_header["number"]),
      gas_limit: load_integer(json_header["gasLimit"]),
      gas_used: load_integer(json_header["gasUsed"]),
      timestamp: load_integer(json_header["timestamp"]),
      extra_data: maybe_hex(json_header["extraData"]),
      mix_hash: maybe_hex(json_header["mixHash"]),
      nonce: maybe_hex(json_header["nonce"])
    }
  end

  defp ommers_from_json(json_ommers) do
    Enum.map(json_ommers || [], fn json_ommer ->
      %Header{
        parent_hash: maybe_hex(json_ommer["parentHash"]),
        ommers_hash: maybe_hex(json_ommer["uncleHash"]),
        beneficiary: maybe_hex(json_ommer["coinbase"]),
        state_root: maybe_hex(json_ommer["stateRoot"]),
        transactions_root: maybe_hex(json_ommer["transactionsTrie"]),
        receipts_root: maybe_hex(json_ommer["receiptTrie"]),
        logs_bloom: maybe_hex(json_ommer["bloom"]),
        difficulty: load_integer(json_ommer["difficulty"]),
        number: load_integer(json_ommer["number"]),
        gas_limit: load_integer(json_ommer["gasLimit"]),
        gas_used: load_integer(json_ommer["gasUsed"]),
        timestamp: load_integer(json_ommer["timestamp"]),
        extra_data: maybe_hex(json_ommer["extraData"]),
        mix_hash: maybe_hex(json_ommer["mixHash"]),
        nonce: maybe_hex(json_ommer["nonce"])
      }
    end)
  end

  defp transactions_from_json(json_transactions) do
    Enum.map(json_transactions || [], fn json_transaction ->
      init =
        if maybe_hex(json_transaction["to"]) == <<>> do
          maybe_hex(json_transaction["data"])
        else
          ""
        end

      %Transaction{
        nonce: load_integer(json_transaction["nonce"]),
        gas_price: load_integer(json_transaction["gasPrice"]),
        gas_limit: load_integer(json_transaction["gasLimit"]),
        to: maybe_hex(json_transaction["to"]),
        value: load_integer(json_transaction["value"]),
        v: load_integer(json_transaction["v"]),
        r: load_integer(json_transaction["r"]),
        s: load_integer(json_transaction["s"]),
        data: maybe_hex(json_transaction["data"]),
        init: init
      }
    end)
  end

  defp populate_prestate(json_test) do
    db = MerklePatriciaTree.Test.random_ets_db()

    state = %Trie{
      db: db,
      root_hash: maybe_hex(json_test["genesisBlockHeader"]["stateRoot"])
    }

    Enum.reduce(json_test["pre"], state, fn {address, account}, state ->
      storage = %Trie{
        root_hash: Trie.empty_trie_root_hash(),
        db: db
      }

      storage =
        Enum.reduce(account["storage"], storage, fn {key, value}, trie ->
          Storage.put(trie.db, trie.root_hash, load_integer(key), load_integer(value))
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
  end

  defp tests do
    wildcard = @ethereum_common_tests_path <> "**/*.json"

    wildcard
    |> Path.wildcard()
    |> Enum.sort()
  end
end
