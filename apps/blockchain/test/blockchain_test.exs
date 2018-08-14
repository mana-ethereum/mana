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
    "Frontier" => [],
    "Homestead" => [],
    "EIP150" => [
      "GeneralStateTests/stSystemOperationsTest/CreateHashCollision_d0g0v0.json"
    ],
    "EIP158" => [
      "GeneralStateTests/stAttackTest/ContractCreationSpam_d0g0v0.json",
      "GeneralStateTests/stAttackTest/CrashingTransaction_d0g0v0.json",
      "GeneralStateTests/stBadOpcode/badOpcodes_d0g0v0.json",
      "GeneralStateTests/stCallCodes/call_OOG_additionalGasCosts1_d0g0v0.json",
      "GeneralStateTests/stCallCodes/callcodeDynamicCode_d0g0v0.json",
      "GeneralStateTests/stCallCreateCallCodeTest/createNameRegistratorPerTxs_d0g0v0.json",
      "GeneralStateTests/stCodeSizeLimit/codesizeOOGInvalidSize_d0g0v0.json",
      "GeneralStateTests/stCodeSizeLimit/codesizeValid_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_AcreateB_BSuicide_BStore_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSSTOREDuringInit_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_ThenStoreThenReturn_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_WithValueToItself_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_WithValue_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_ContractSuicideDuringInit_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateEContractInInit_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateNEContractInInitOOG_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContractCreateNEContractInInit_Tr_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EContract_ThenCALLToNonExistentAcc_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractAndCallIt_0wei_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractAndCallIt_1wei_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractWithBalance_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractWithStorageAndCallIt_0wei_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractWithStorageAndCallIt_1wei_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContractWithStorage_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_EmptyContract_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CREATE_empty000CreateinInitCode_Transaction_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CreateCollisionToEmpty_d0g0v0.json",
      "GeneralStateTests/stCreateTest/CreateCollisionToEmpty_d0g0v1.json",
      "GeneralStateTests/stCreateTest/TransactionCollisionToEmpty_d0g0v0.json",
      "GeneralStateTests/stCreateTest/TransactionCollisionToEmpty_d0g0v1.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode_d0g0v0.json",
      "GeneralStateTests/stEIP158Specific/CALL_OneVCallSuicide_d0g0v0.json",
      "GeneralStateTests/stEIP158Specific/CALL_ZeroVCallSuicide_d0g0v0.json",
      "GeneralStateTests/stEIP158Specific/vitalikTransactionTest_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallContractToCreateContractAndCallItOOG_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallContractToCreateContractOOGBonusGas_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallContractToCreateContractOOG_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallContractToCreateContractWhichWouldCreateContractIfCalled_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallContractToCreateContractWhichWouldCreateContractInInitCode_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallRecursiveContract_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallTheContractToCreateEmptyContract_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/TransactionCreateAutoSuicideContract_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/TransactionCreateStopInInitcode_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/CreateAndGasInsideCreateWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/NewGasPriceForCodesWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_CALL_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_CALL_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_SUICIDE_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_SUICIDE_ToNonNonZeroBalance_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_SUICIDE_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_SUICIDE_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_0input_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_Gas2999_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_completeReturnValue_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_gas3000_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover0_overlappingInputOutput_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover1_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover2_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover3_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecover80_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverCheckLengthWrongV_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverCheckLength_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverH_prefixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverR_prefixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverS_prefixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallEcrecoverV_prefixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentitiy_0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentitiy_1_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_2_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_3_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_4_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_4_gas17_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_4_gas18_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallIdentity_5_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_1_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_2_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_3_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_3_postfixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_3_prefixed0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_4_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_4_gas719_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallRipemd160_5_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_1_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_2_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_3_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_3_postfix0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_3_prefix0_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_4_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_4_gas99_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts2/CallSha256_5_d0g0v0.json",
      "GeneralStateTests/stQuadraticComplexityTest/Create1000Byzantium_d0g1v0.json",
      "GeneralStateTests/stQuadraticComplexityTest/Create1000_d0g1v0.json",
      "GeneralStateTests/stRecursiveCreate/recursiveCreateReturnValue_d0g0v0.json",
      "GeneralStateTests/stRecursiveCreate/recursiveCreate_d0g0v0.json",
      "GeneralStateTests/stRefundTest/refundSuicide50procentCap_d1g0v0.json",
      "GeneralStateTests/stRefundTest/refund_CallToSuicideNoStorage_d1g0v0.json",
      "GeneralStateTests/stRefundTest/refund_CallToSuicideStorage_d1g0v0.json",
      "GeneralStateTests/stRefundTest/refund_CallToSuicideTwice_d1g0v0.json",
      "GeneralStateTests/stRefundTest/refund_TxToSuicide_d0g1v0.json",
      "GeneralStateTests/stRefundTest/refund_multimpleSuicide_d0g0v0.json",
      "GeneralStateTests/stRefundTest/refund_singleSuicide_d0g0v0.json",
      "GeneralStateTests/stRevertTest/LoopCallsDepthThenRevert2_d0g0v0.json",
      "GeneralStateTests/stRevertTest/LoopCallsDepthThenRevert3_d0g0v0.json",
      "GeneralStateTests/stRevertTest/NashatyrevSuicideRevert_d0g0v0.json",
      "GeneralStateTests/stRevertTest/RevertDepthCreateOOG_d1g1v0.json",
      "GeneralStateTests/stRevertTest/RevertDepthCreateOOG_d1g1v1.json",
      "GeneralStateTests/stRevertTest/RevertPrefoundEmptyCall_d0g0v0.json",
      "GeneralStateTests/stRevertTest/RevertPrefoundEmpty_d0g0v0.json",
      "GeneralStateTests/stRevertTest/RevertPrefound_d0g0v0.json",
      "GeneralStateTests/stRevertTest/RevertRemoteSubCallStorageOOG2_d0g1v0.json",
      "GeneralStateTests/stRevertTest/RevertRemoteSubCallStorageOOG_d0g1v0.json",
      "GeneralStateTests/stRevertTest/TouchToEmptyAccountRevert3_d0g0v0.json",
      "GeneralStateTests/stSolidityTest/CreateContractFromMethod_d0g0v0.json",
      "GeneralStateTests/stSolidityTest/RecursiveCreateContractsCreate4Contracts_d0g0v0.json",
      "GeneralStateTests/stSolidityTest/RecursiveCreateContracts_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/StackDepthLimitSEC_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/deploymentError_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/failed_tx_xcf416c53_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/tx_e1c174e2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcallsSuicide0_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcallsSuicide1_d1g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CreateHashCollision_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/createNameRegistratorZeroMem2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/createNameRegistratorZeroMemExpansion_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/createNameRegistratorZeroMem_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/createNameRegistrator_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/doubleSelfdestructTest2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/doubleSelfdestructTest_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/extcodecopy_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideAddress_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideCallerAddresTooBigLeft_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideCallerAddresTooBigRight_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideCaller_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideCoinbase_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideNotExistingAccount_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideOrigin_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideSendEtherPostDeath_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideSendEtherToMe_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/testRandomTest_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/CreateMessageSuccess_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/CreateTransactionSuccess_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/EmptyTransaction2_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/EmptyTransaction3_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d120g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d124g0v0.json",
      "GeneralStateTests/stTransactionTest/Opcodes_TransactionInit_d127g0v0.json",
      "GeneralStateTests/stTransactionTest/OverflowGasRequire2_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/StoreGasOnCreate_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndInternlCallSuicidesBonusGasAtCallFailed_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndInternlCallSuicidesBonusGasAtCall_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndInternlCallSuicidesOOG_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndInternlCallSuicidesSuccess_d1g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndSendMoneyToItselfEtherDestroyed_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesMixingCoinbase_d0g1v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesStopAfterSuicide_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/TransactionDataCosts652_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/TransactionSendingToEmpty_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsAfter_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsAt_d0g0v0.json",
      "GeneralStateTests/stTransitionTest/createNameRegistratorPerTxsBefore_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstructionPartial_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstruction_d0g0v0.json",
      "GeneralStateTests/stWalletTest/dayLimitConstruction_d0g1v0.json",
      "GeneralStateTests/stWalletTest/multiOwnedConstructionCorrect_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstructionOOG_d0g1v0.json",
      "GeneralStateTests/stWalletTest/walletConstructionPartial_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstruction_d0g0v0.json",
      "GeneralStateTests/stWalletTest/walletConstruction_d0g1v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_CALL_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_CALL_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_CALL_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_SUICIDE_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_SUICIDE_ToNonZeroBalance_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_SUICIDE_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_SUICIDE_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALL_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALL_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALL_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALLwithData_ToEmpty_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALLwithData_ToOneStorageKey_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_TransactionCALLwithData_d0g0v0.json",
      "bcBlockGasLimitTest/GasUsedHigherThanBlockGasLimitButNotWithRefundsSuicideFirst.json",
      "bcBlockGasLimitTest/SuicideTransaction.json",
      "bcExploitTest/StrangeContractCreation.json",
      "bcExploitTest/SuicideIssue.json",
      "bcGasPricerTest/RPC_API_Test.json",
      "bcMultiChainTest/CallContractFromNotBestBlock.json",
      "bcRandomBlockhashTest/randomStatetest193BC.json",
      "bcRandomBlockhashTest/randomStatetest344BC.json",
      "bcStateTests/OOGStateCopyContainingDeletedContract.json",
      "bcStateTests/simpleSuicide.json",
      "bcStateTests/suicideCoinbase.json",
      "bcTotalDifficultyTest/lotsOfLeafs.json",
      "bcValidBlockTest/RecallSuicidedContract.json",
      "bcValidBlockTest/RecallSuicidedContractInOneBlock.json",
      "bcWalletTest/wallet2outOf3txs2.json",
      "bcWalletTest/wallet2outOf3txsRevoke.json",
      "bcWalletTest/wallet2outOf3txsRevokeAndConfirmAgain.json",
      "bcWalletTest/walletReorganizeOwners.json"
    ],
    # the rest are not implemented yet
    "Byzantium" => [],
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
      |> Enum.each(fn {name, test} ->
        if !failing_test?(json_test_path, test) do
          run_test(name, test)
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

  defp run_test(test_name, json_test) do
    fork = json_test["network"]
    chain = load_chain(fork)

    if chain do
      state = populate_prestate(json_test)

      blocktree =
        create_blocktree()
        |> add_genesis_block(json_test, state, chain)
        |> add_blocks(json_test, state, chain)

      best_block_hash = maybe_hex(json_test["lastblockhash"])

      assert blocktree.best_block.block_hash == best_block_hash, failure_message(test_name, fork)
    end
  end

  defp failure_message(test_name, fork) do
    "Block hash mismatch in test #{test_name} for #{fork}"
  end

  defp load_chain(hardfork) do
    config = evm_config(hardfork)

    case hardfork do
      "Frontier" ->
        Chain.load_chain(:frontier_test, config)

      "Homestead" ->
        Chain.load_chain(:homestead_test, config)

      "EIP150" ->
        Chain.load_chain(:eip150_test, config)

      "EIP158" ->
        Chain.load_chain(:eip150_test, config)

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

      "EIP150" ->
        EVM.Configuration.EIP150.new()

      "EIP158" ->
        EVM.Configuration.EIP158.new()

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
