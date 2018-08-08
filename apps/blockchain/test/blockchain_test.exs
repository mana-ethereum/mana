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
    "Homestead" => [
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode_d0g0v0.json"
    ],
    "EIP150" => [
      "GeneralStateTests/stChangedEIP150/Call1024BalanceTooLow_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/Call1024PreCalls_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/Callcode1024BalanceTooLow_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcall_00_OOGE_1_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcall_00_OOGE_2_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/callcall_00_OOGE_valueTransfer_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/contractCreationMakeCallThatAskMoreGasThenTransactionProvided_d0g0v0.json",
      "GeneralStateTests/stChangedEIP150/contractCreationMakeCallThatAskMoreGasThenTransactionProvided_d0g1v0.json",
      "GeneralStateTests/stCreateTest/CREATE_AcreateB_BSuicide_BStore_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Delegatecall1024OOG_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/Delegatecall1024_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecallAndOOGatTxLevel_d0g0v0.json",
      "GeneralStateTests/stDelegatecallTestHomestead/delegatecodeDynamicCode_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/CallAndCallcodeConsumeMoreGasThenTransactionHas_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/CallAskMoreGasOnDepth2ThenTransactionHas_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/CreateAndGasInsideCreate_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/DelegateCallOnEIP_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/ExecuteCallThatAskForeGasThenTrabsactionHas_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/SuicideToNotExistingContract_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/Transaction64Rule_d64e0_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/Transaction64Rule_d64m1_d0g0v0.json",
      "GeneralStateTests/stEIP150Specific/Transaction64Rule_d64p1_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallCodeGasAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallCodeGasMemoryAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallCodeGasValueTransferAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallCodeGasValueTransferMemoryAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallGasAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallGasValueTransferAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallGasValueTransferMemoryAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawCallMemoryGasAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawDelegateCallGasAsk_d0g0v0.json",
      "GeneralStateTests/stEIP150singleCodeGasPrices/RawDelegateCallGasMemoryAsk_d0g0v0.json",
      "GeneralStateTests/stEIP158Specific/vitalikTransactionTest_d0g0v0.json",
      "GeneralStateTests/stInitCodeTest/CallRecursiveContract_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/CallAndCallcodeConsumeMoreGasThenTransactionHasWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/CallAskMoreGasOnDepth2ThenTransactionHasWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/CreateAndGasInsideCreateWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/DelegateCallOnEIPWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stMemExpandingEIP150Calls/ExecuteCallThatAskMoreGasThenTransactionHasWithMemExpandingCalls_d0g0v0.json",
      "GeneralStateTests/stNonZeroCallsTest/NonZeroValue_SUICIDE_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d0g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d0g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d0g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d0g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d10g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d10g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d10g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d10g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d11g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d11g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d11g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d11g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d12g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d12g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d12g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d12g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d13g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d13g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d13g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d13g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d14g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d14g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d14g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d14g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d15g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d15g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d15g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d15g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d16g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d16g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d16g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d16g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d17g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d17g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d17g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d17g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d18g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d18g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d18g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d18g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d19g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d19g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d19g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d19g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d1g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d1g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d1g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d1g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d20g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d20g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d20g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d20g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d21g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d21g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d21g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d21g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d22g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d22g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d22g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d22g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d23g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d23g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d23g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d23g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d24g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d24g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d24g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d24g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d25g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d25g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d25g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d25g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d26g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d26g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d26g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d26g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d27g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d27g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d27g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d27g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d28g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d28g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d28g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d28g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d29g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d29g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d29g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d29g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d2g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d2g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d2g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d2g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d30g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d30g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d30g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d30g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d31g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d31g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d31g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d31g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d32g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d32g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d32g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d32g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d33g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d33g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d33g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d33g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d34g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d34g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d34g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d34g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d35g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d35g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d35g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d35g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d36g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d36g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d36g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d36g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d3g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d3g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d3g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d3g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d4g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d4g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d4g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d4g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d5g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d5g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d5g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d5g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d6g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d6g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d6g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d6g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d7g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d7g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d7g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d7g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d8g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d8g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d8g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d8g3v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d9g0v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d9g1v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d9g2v0.json",
      "GeneralStateTests/stPreCompiledContracts/modexp_d9g3v0.json",
      "GeneralStateTests/stRecursiveCreate/recursiveCreateReturnValue_d0g0v0.json",
      "GeneralStateTests/stRecursiveCreate/recursiveCreate_d0g0v0.json",
      "GeneralStateTests/stRefundTest/refund_TxToSuicide_d0g1v0.json",
      "GeneralStateTests/stRevertTest/LoopCallsDepthThenRevert_d0g0v0.json",
      "GeneralStateTests/stRevertTest/LoopDelegateCallsDepthThenRevert_d0g0v0.json",
      "GeneralStateTests/stRevertTest/RevertDepthCreateOOG_d1g1v0.json",
      "GeneralStateTests/stRevertTest/RevertDepthCreateOOG_d1g1v1.json",
      "GeneralStateTests/stRevertTest/RevertRemoteSubCallStorageOOG2_d0g1v0.json",
      "GeneralStateTests/stRevertTest/RevertRemoteSubCallStorageOOG_d0g1v0.json",
      "GeneralStateTests/stSolidityTest/RecursiveCreateContractsCreate4Contracts_d0g0v0.json",
      "GeneralStateTests/stSolidityTest/RecursiveCreateContracts_d0g0v0.json",
      "GeneralStateTests/stSpecialTest/tx_e1c174e2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcalls1_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcalls2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcalls3_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/ABAcallsSuicide1_d1g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBomb0_OOG_atMaxCallDepth_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBomb0_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBomb1_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBomb2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBomb3_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBombLog2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CallRecursiveBombLog_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/CreateHashCollision_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/createWithInvalidOpcode_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/doubleSelfdestructTest2_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/doubleSelfdestructTest_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/extcodecopy_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideCallerAddresTooBigRight_d0g0v0.json",
      "GeneralStateTests/stSystemOperationsTest/suicideNotExistingAccount_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/InternalCallHittingGasLimit2_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/StoreGasOnCreate_d0g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesAndInternlCallSuicidesSuccess_d1g0v0.json",
      "GeneralStateTests/stTransactionTest/SuicidesMixingCoinbase_d0g1v0.json",
      "GeneralStateTests/stWalletTest/walletConfirm_d0g0v0.json",
      "GeneralStateTests/stZeroCallsTest/ZeroValue_SUICIDE_d0g0v0.json",
      "bcForkStressTest/AmIOnEIP150.json",
      "bcRandomBlockhashTest/randomStatetest344BC.json",
      "bcRandomBlockhashTest/randomStatetest65BC.json",
      "bcStateTests/OOGStateCopyContainingDeletedContract.json",
      "bcValidBlockTest/RecallSuicidedContract.json",
      "bcValidBlockTest/RecallSuicidedContractInOneBlock.json",
      "bcWalletTest/wallet2outOf3txs2.json",
      "bcWalletTest/wallet2outOf3txsRevokeAndConfirmAgain.json"
    ],
    # the rest are not implemented yet
    "Byzantium" => [],
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

      "EIP150" ->
        EVM.Configuration.EIP150.new()

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
