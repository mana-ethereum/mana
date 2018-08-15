defmodule Blockchain.StateTest do
  alias MerklePatriciaTree.Trie
  alias Blockchain.{Account, Transaction}
  alias Blockchain.Interface.AccountInterface
  alias Blockchain.Account.Storage
  alias ExthCrypto.Hash.Keccak

  use EthCommonTest.Harness
  use ExUnit.Case, async: true

  @failing_tests %{
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
      "stSystemOperationsTest/CreateHashCollision",
      "stRevertTest/RevertOpcodeWithBigOutputInInit",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/RevertOpcodeInInit",
      "stRandom2/201503110226PYTHON_DUP6",
      "stInitCodeTest/OutOfGasPrefundedContractCreation",
      "stInitCodeTest/OutOfGasContractCreation",
      "stInitCodeTest/NotEnoughCashContractCreation"
    ],
    "EIP158" => [
      "stZeroCallsTest/ZeroValue_TransactionCALLwithData_ToOneStorageKey",
      "stZeroCallsTest/ZeroValue_TransactionCALLwithData_ToEmpty",
      "stZeroCallsTest/ZeroValue_TransactionCALLwithData",
      "stZeroCallsTest/ZeroValue_TransactionCALL_ToOneStorageKey",
      "stZeroCallsTest/ZeroValue_TransactionCALL_ToEmpty",
      "stZeroCallsTest/ZeroValue_TransactionCALL",
      "stZeroCallsTest/ZeroValue_SUICIDE_ToOneStorageKey",
      "stZeroCallsTest/ZeroValue_SUICIDE_ToNonZeroBalance",
      "stZeroCallsTest/ZeroValue_SUICIDE_ToEmpty",
      "stZeroCallsTest/ZeroValue_SUICIDE",
      "stZeroCallsTest/ZeroValue_CALL_ToOneStorageKey",
      "stZeroCallsTest/ZeroValue_CALL_ToEmpty",
      "stZeroCallsTest/ZeroValue_CALL",
      "stTransactionTest/UserTransactionZeroCostWithData",
      "stTransactionTest/UserTransactionZeroCost",
      "stTransactionTest/TransactionDataCosts652",
      "stTransactionTest/SuicidesStopAfterSuicide",
      "stTransactionTest/SuicidesMixingCoinbase",
      "stTransactionTest/SuicidesAndSendMoneyToItselfEtherDestroyed",
      "stTransactionTest/SuicidesAndInternlCallSuicidesSuccess",
      "stTransactionTest/SuicidesAndInternlCallSuicidesOOG",
      "stTransactionTest/SuicidesAndInternlCallSuicidesBonusGasAtCallFailed",
      "stTransactionTest/SuicidesAndInternlCallSuicidesBonusGasAtCall",
      "stTransactionTest/OverflowGasRequire2",
      "stTransactionTest/Opcodes_TransactionInit",
      "stTransactionTest/EmptyTransaction2",
      "stSystemOperationsTest/suicideSendEtherToMe",
      "stSystemOperationsTest/suicideSendEtherPostDeath",
      "stSystemOperationsTest/suicideOrigin",
      "stSystemOperationsTest/suicideNotExistingAccount",
      "stSystemOperationsTest/suicideCoinbase",
      "stSystemOperationsTest/suicideCallerAddresTooBigRight",
      "stSystemOperationsTest/suicideCallerAddresTooBigLeft",
      "stSystemOperationsTest/suicideCaller",
      "stSystemOperationsTest/suicideAddress",
      "stSystemOperationsTest/extcodecopy",
      "stSystemOperationsTest/doubleSelfdestructTest2",
      "stSystemOperationsTest/doubleSelfdestructTest",
      "stSystemOperationsTest/CreateHashCollision",
      "stSystemOperationsTest/ABAcallsSuicide1",
      "stSystemOperationsTest/ABAcallsSuicide0",
      "stSpecialTest/tx_e1c174e2",
      "stSpecialTest/failed_tx_xcf416c53",
      "stRevertTest/TouchToEmptyAccountRevert3",
      "stRevertTest/RevertPrefoundEmptyCall",
      "stRevertTest/RevertPrefound",
      "stRevertTest/RevertOpcodeMultipleSubCalls",
      "stRevertTest/NashatyrevSuicideRevert",
      "stRefundTest/refund_singleSuicide",
      "stRefundTest/refund_multimpleSuicide",
      "stRefundTest/refund_TxToSuicide",
      "stRefundTest/refund_CallToSuicideTwice",
      "stRefundTest/refund_CallToSuicideStorage",
      "stRefundTest/refund_CallToSuicideNoStorage",
      "stRefundTest/refundSuicide50procentCap",
      "stPreCompiledContracts2/CallSha256_4_gas99",
      "stPreCompiledContracts2/CallSha256_4",
      "stPreCompiledContracts2/CallSha256_3_prefix0",
      "stPreCompiledContracts2/CallSha256_3_postfix0",
      "stPreCompiledContracts2/CallSha256_3",
      "stPreCompiledContracts2/CallSha256_2",
      "stPreCompiledContracts2/CallSha256_1",
      "stPreCompiledContracts2/CallSha256_0",
      "stPreCompiledContracts2/CallRipemd160_4",
      "stPreCompiledContracts2/CallRipemd160_3_prefixed0",
      "stPreCompiledContracts2/CallRipemd160_3_postfixed0",
      "stPreCompiledContracts2/CallRipemd160_3",
      "stPreCompiledContracts2/CallRipemd160_2",
      "stPreCompiledContracts2/CallRipemd160_1",
      "stPreCompiledContracts2/CallIdentity_4_gas18",
      "stPreCompiledContracts2/CallIdentity_4",
      "stPreCompiledContracts2/CallIdentity_3",
      "stPreCompiledContracts2/CallIdentity_2",
      "stPreCompiledContracts2/CallIdentitiy_1",
      "stPreCompiledContracts2/CallIdentitiy_0",
      "stPreCompiledContracts2/CallEcrecoverV_prefixed0",
      "stPreCompiledContracts2/CallEcrecoverS_prefixed0",
      "stPreCompiledContracts2/CallEcrecoverR_prefixed0",
      "stPreCompiledContracts2/CallEcrecoverH_prefixed0",
      "stPreCompiledContracts2/CallEcrecoverCheckLengthWrongV",
      "stPreCompiledContracts2/CallEcrecoverCheckLength",
      "stPreCompiledContracts2/CallEcrecover80",
      "stPreCompiledContracts2/CallEcrecover3",
      "stPreCompiledContracts2/CallEcrecover2",
      "stPreCompiledContracts2/CallEcrecover1",
      "stPreCompiledContracts2/CallEcrecover0_overlappingInputOutput",
      "stPreCompiledContracts2/CallEcrecover0_gas3000",
      "stPreCompiledContracts2/CallEcrecover0_completeReturnValue",
      "stPreCompiledContracts2/CallEcrecover0_0input",
      "stPreCompiledContracts2/CallEcrecover0",
      "stNonZeroCallsTest/NonZeroValue_SUICIDE_ToOneStorageKey",
      "stNonZeroCallsTest/NonZeroValue_SUICIDE_ToNonNonZeroBalance",
      "stNonZeroCallsTest/NonZeroValue_SUICIDE_ToEmpty",
      "stNonZeroCallsTest/NonZeroValue_SUICIDE",
      "stNonZeroCallsTest/NonZeroValue_CALL_ToOneStorageKey",
      "stNonZeroCallsTest/NonZeroValue_CALL_ToEmpty",
      "stMemExpandingEIP150Calls/NewGasPriceForCodesWithMemExpandingCalls",
      "stInitCodeTest/TransactionCreateAutoSuicideContract",
      "stInitCodeTest/CallContractToCreateContractOOG",
      "stEIP158Specific/vitalikTransactionTest",
      "stEIP158Specific/CALL_ZeroVCallSuicide",
      "stEIP158Specific/CALL_OneVCallSuicide",
      "stCreateTest/CREATE_EContract_ThenCALLToNonExistentAcc",
      "stCreateTest/CREATE_ContractSuicideDuringInit_WithValueToItself",
      "stCreateTest/CREATE_ContractSuicideDuringInit_WithValue",
      "stCreateTest/CREATE_ContractSuicideDuringInit_ThenStoreThenReturn",
      "stCreateTest/CREATE_ContractSuicideDuringInit",
      "stCreateTest/CREATE_AcreateB_BSuicide_BStore",
      "stCallCodes/call_OOG_additionalGasCosts1",
      "stAttackTest/CrashingTransaction",
      "stAttackTest/ContractCreationSpam"
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
