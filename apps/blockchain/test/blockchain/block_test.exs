defmodule Blockchain.BlockTest do
  use ExUnit.Case, async: true
  import EthCommonTest.Helpers

  doctest Blockchain.Block

  alias Block.Header
  alias Blockchain.BlockGetter
  alias Blockchain.{Account, Block, Chain, Genesis, Transaction}
  alias Blockchain.Transaction.Receipt
  alias Blockchain.Transaction.Signature
  alias EVM.MachineCode
  alias MerklePatriciaTree.Trie

  test "eth common tests" do
    EthCommonTest.Helpers.run_common_tests(
      "GenesisTests",
      &ExUnit.Assertions.flunk/1,
      fn _test_name, test_case ->
        db = MerklePatriciaTree.Test.random_ets_db()
        trie = MerklePatriciaTree.Trie.new(db)

        chain = %Chain{
          genesis: %{
            timestamp: maybe_hex(test_case["timestamp"]),
            parent_hash: maybe_hex(test_case["parentHash"]),
            extra_data: maybe_hex(test_case["extraData"]),
            gas_limit: maybe_hex(test_case["gasLimit"]),
            difficulty: maybe_hex(test_case["difficulty"]),
            author: maybe_hex(test_case["coinbase"]),
            seal: %{
              mix_hash: maybe_hex(test_case["mixHash"]),
              nonce: maybe_hex(test_case["nonce"])
            }
          },
          accounts: get_test_accounts(test_case["alloc"])
        }

        {block, _} = Genesis.create_block(chain, trie)

        # Check that our block matches the serialization from common tests
        assert Block.serialize(block) ==
                 test_case["result"]
                 |> maybe_hex()
                 |> ExRLP.decode()
      end
    )
  end

  defp get_test_accounts(alloc) do
    for {k, v} <- alloc do
      {k |> load_raw_hex,
       %{
         balance: (v["balance"] || v["wei"] || "0") |> load_decimal(),
         storage: get_storage(v["storage"])
       }}
    end
  end

  defp get_storage(nil), do: %{}

  defp get_storage(storage) when is_map(storage) do
    for {k, v} <- storage do
      {k |> maybe_hex(:integer), v |> maybe_hex(:integer)}
    end
    |> Enum.into(%{})
  end

  describe "add_rewards/3" do
    test "rewards the miner and ommers" do
      db = MerklePatriciaTree.Test.random_ets_db()
      trie = MerklePatriciaTree.Trie.new(db)
      miner = <<0x05::160>>
      ommer = <<0x06::160>>
      state = MerklePatriciaTree.Trie.new(db)
      chain = Chain.load_chain(:ropsten)

      block = %Blockchain.Block{
        header: %Header{
          number: 3,
          state_root: state.root_hash,
          beneficiary: miner
        },
        ommers: [
          %Header{
            number: 1,
            beneficiary: ommer
          }
        ]
      }

      {block, _trie} = Blockchain.Block.add_rewards(block, trie, chain)

      miner_balance =
        block
        |> BlockGetter.get_state(trie)
        |> Account.get_account(miner)
        |> Map.get(:balance)

      ommer_balance =
        block
        |> BlockGetter.get_state(trie)
        |> Account.get_account(ommer)
        |> Map.get(:balance)

      assert miner_balance == round(515_625.0e13)
      assert ommer_balance == round(375.0e16)
    end

    test "rewards the miner and ommers with Byzantium rewards" do
      db = MerklePatriciaTree.Test.random_ets_db()
      trie = MerklePatriciaTree.Trie.new(db)
      miner = <<0x05::160>>
      ommer = <<0x06::160>>
      state = MerklePatriciaTree.Trie.new(db)
      chain = Chain.load_chain(:ropsten)

      {byzantium_block_number, _} =
        chain.engine["Ethash"][:block_rewards]
        |> Enum.at(1)

      block = %Blockchain.Block{
        header: %Header{
          number: byzantium_block_number,
          state_root: state.root_hash,
          beneficiary: miner
        },
        ommers: [
          %Header{
            number: byzantium_block_number - 2,
            beneficiary: ommer
          }
        ]
      }

      {block, trie} = Blockchain.Block.add_rewards(block, trie, chain)

      miner_balance =
        block
        |> BlockGetter.get_state(trie)
        |> Blockchain.Account.get_account(miner)
        |> Map.get(:balance)

      ommer_balance =
        block
        |> BlockGetter.get_state(trie)
        |> Blockchain.Account.get_account(ommer)
        |> Map.get(:balance)

      assert miner_balance == round(309_375.0e13)
      assert ommer_balance == round(225.0e16)
    end
  end

  test "serialize and deserialize a block is lossless" do
    block = %Block{
      header: %Header{
        parent_hash: <<1::256>>,
        ommers_hash: <<2::256>>,
        beneficiary: <<3::160>>,
        state_root: <<4::256>>,
        transactions_root: <<5::256>>,
        receipts_root: <<6::256>>,
        logs_bloom: <<>>,
        difficulty: 5,
        number: 1,
        gas_limit: 5,
        gas_used: 3,
        timestamp: 6,
        extra_data: "Hi mom",
        mix_hash: <<7::256>>,
        nonce: <<8::64>>
      },
      transactions: [
        %Transaction{
          nonce: 5,
          gas_price: 6,
          gas_limit: 7,
          to: <<1::160>>,
          value: 8,
          v: 27,
          r: 9,
          s: 10,
          data: "hi"
        }
      ],
      ommers: [
        %Header{
          parent_hash: <<11::256>>,
          ommers_hash: <<12::256>>,
          beneficiary: <<13::160>>,
          state_root: <<14::256>>,
          transactions_root: <<15::256>>,
          receipts_root: <<16::256>>,
          logs_bloom: <<>>,
          difficulty: 5,
          number: 1,
          gas_limit: 5,
          gas_used: 3,
          timestamp: 6,
          extra_data: "Hi mom",
          mix_hash: <<17::256>>,
          nonce: <<18::64>>
        }
      ]
    }

    assert block ==
             block |> Block.serialize() |> ExRLP.encode() |> ExRLP.decode() |> Block.deserialize()
  end

  test "validate" do
    db = MerklePatriciaTree.Test.random_ets_db()
    trie = MerklePatriciaTree.Trie.new(db)
    chain = Blockchain.Test.ropsten_chain()
    {parent, new_trie} = Blockchain.Genesis.create_block(chain, trie)
    beneficiary = <<0x05::160>>

    child =
      parent
      |> Blockchain.Block.gen_child_block(chain, beneficiary: beneficiary)

    {child, _new_trie} = Blockchain.Block.add_rewards(child, new_trie, chain)

    {result, _} = Blockchain.Block.validate(child, chain, parent, trie)

    assert result == :valid
  end

  test "match genesis block on ropsten" do
    db = MerklePatriciaTree.Test.random_ets_db()
    trie = MerklePatriciaTree.Trie.new(db)
    chain = Blockchain.Test.ropsten_chain()

    {block, updated_trie} = Genesis.create_block(chain, trie)

    {block, _updated_trie} = Block.add_rewards(block, updated_trie, chain)

    block =
      block
      |> put_header(:mix_hash, <<0::256>>)
      |> put_header(:nonce, <<0x42::64>>)

    block = %{block | block_hash: Block.hash(block)}

    assert block ==
             %Blockchain.Block{
               block_hash:
                 <<65, 148, 16, 35, 104, 9, 35, 224, 254, 77, 116, 163, 75, 218, 200, 20, 31, 37,
                   64, 227, 174, 144, 98, 55, 24, 228, 125, 102, 209, 202, 74, 45>>,
               header: %Header{
                 beneficiary: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 difficulty: 1_048_576,
                 extra_data: "55555555555555555555555555555555",
                 gas_limit: 16_777_216,
                 gas_used: 0,
                 logs_bloom: <<0::2048>>,
                 mix_hash:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0>>,
                 nonce: <<0, 0, 0, 0, 0, 0, 0, 66>>,
                 number: 0,
                 ommers_hash:
                   <<29, 204, 77, 232, 222, 199, 93, 122, 171, 133, 181, 103, 182, 204, 212, 26,
                     211, 18, 69, 27, 148, 138, 116, 19, 240, 161, 66, 253, 64, 212, 147, 71>>,
                 parent_hash:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                     0, 0, 0, 0, 0, 0>>,
                 receipts_root:
                   <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91,
                     72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>,
                 state_root:
                   <<33, 123, 11, 188, 251, 114, 226, 213, 126, 40, 243, 60, 179, 97, 185, 152,
                     53, 19, 23, 119, 85, 220, 63, 51, 206, 62, 112, 34, 237, 98, 183, 123>>,
                 timestamp: 0,
                 transactions_root:
                   <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91,
                     72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
               },
               ommers: [],
               transactions: []
             }
  end

  test "assert fully valid genesis block on ropsten" do
    db = MerklePatriciaTree.Test.random_ets_db()
    trie = MerklePatriciaTree.Trie.new(db)
    chain = Blockchain.Test.ropsten_chain()

    {block, _} = Genesis.create_block(chain, trie)
    {block, _} = Block.add_rewards(block, trie, chain)
    {result, _} = Block.validate(block, chain, nil, trie)

    assert result == :valid
  end

  describe "add_transactions/3" do
    test "creates contract account" do
      chain = Blockchain.Test.frontier_chain()
      db = MerklePatriciaTree.Test.random_ets_db()
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      assembly = [
        :push1,
        3,
        :push1,
        5,
        :add,
        :push1,
        0x00,
        :mstore,
        :push1,
        32,
        :push1,
        0,
        :return
      ]

      machine_code = MachineCode.compile(assembly)

      trx =
        %Transaction{
          nonce: 5,
          gas_price: 3,
          gas_limit: 100_000,
          to: <<>>,
          value: 5,
          init: machine_code
        }
        |> Transaction.Signature.sign_transaction(private_key)

      account = %Account{balance: 400_000, nonce: 5}

      state =
        db
        |> Trie.new()
        |> Account.put_account(sender, account)

      block_header = %Header{
        number: 0,
        state_root: state.root_hash,
        beneficiary: beneficiary,
        gas_limit: 900_000_000
      }

      block = %Block{header: block_header, transactions: []}
      {block, _} = Block.add_transactions(block, [trx], state, chain)

      assert Enum.count(block.transactions) == 1

      expected_receipt = %Blockchain.Transaction.Receipt{
        cumulative_gas: 28_180,
        logs: [],
        state: block.header.state_root
      }

      assert Block.get_receipt(block, 0, db) == expected_receipt

      expected_transaction = %Transaction{
        data: "",
        gas_limit: 100_000,
        gas_price: 3,
        init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 32, 96, 0, 243>>,
        nonce: 5,
        r:
          107_081_699_003_708_865_501_096_995_082_166_450_904_153_826_331_883_689_397_382_301_082_384_794_234_940,
        s:
          15_578_885_506_929_783_846_367_818_105_804_923_093_083_001_199_223_955_674_477_534_036_059_482_186_127,
        to: "",
        v: 27,
        value: 5
      }

      assert Block.get_transaction(block, 0, db) == expected_transaction

      contract_address = Account.Address.new(sender, 6)
      addresses = [sender, beneficiary, contract_address]

      actual_accounts =
        block
        |> BlockGetter.get_state(MerklePatriciaTree.Trie.new(db))
        |> Account.get_accounts(addresses)

      expected_accounts = [
        %Blockchain.Account{balance: 315_455, nonce: 6},
        %Blockchain.Account{balance: 84_540},
        %Blockchain.Account{
          balance: 5,
          nonce: 0,
          code_hash:
            <<243, 247, 169, 254, 54, 79, 170, 185, 59, 33, 109, 165, 10, 50, 20, 21, 79, 34, 160,
              162, 180, 21, 178, 58, 132, 200, 22, 158, 139, 99, 110, 227>>
        }
      ]

      assert actual_accounts == expected_accounts
    end
  end

  describe "get_block/2" do
    test "empty Trie, get by hash => not found" do
      trie = MerklePatriciaTree.Test.random_ets_db() |> Trie.new()
      result = Block.get_block(<<1, 2, 3>>, trie)

      assert result == :not_found
    end

    test "populated Trie, get by hash found" do
      db = MerklePatriciaTree.Test.random_ets_db()
      trie = db |> Trie.new()

      block = %Block{
        block_hash:
          <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238,
            155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>,
        transactions: [
          %Transaction{
            nonce: 5,
            gas_price: 6,
            gas_limit: 7,
            to: <<1::160>>,
            value: 8,
            v: 27,
            r: 9,
            s: 10,
            data: "hi"
          }
        ],
        header: %Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>,
          size: 447,
          total_difficulty: 100
        }
      }

      Block.put_block(block, trie)
      result = Block.get_block(block |> Block.hash(), trie)

      assert result == {:ok, block}
    end

    test "empty Trie, get by number => not found" do
      trie = MerklePatriciaTree.Test.random_ets_db() |> Trie.new()
      result = Block.get_block(1, trie)

      assert result == :not_found
    end

    test "Populated Trie, result found, wrong key, result not found" do
      db = MerklePatriciaTree.Test.random_ets_db()
      trie = db |> Trie.new()

      block = %Block{
        block_hash:
          <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238,
            155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>,
        transactions: [
          %Transaction{
            nonce: 5,
            gas_price: 6,
            gas_limit: 7,
            to: <<1::160>>,
            value: 8,
            v: 27,
            r: 9,
            s: 10,
            data: "hi"
          }
        ],
        header: %Header{
          number: 5,
          parent_hash: <<1, 2, 3>>,
          beneficiary: <<2, 3, 4>>,
          difficulty: 100,
          timestamp: 11,
          mix_hash: <<1>>,
          nonce: <<2>>,
          size: 447,
          total_difficulty: 100
        }
      }

      Block.put_block(block, trie)
      found_result = Block.get_block(5, trie)
      not_found_result = Block.get_block(6, trie)

      assert found_result == {:ok, block}
      assert not_found_result == :not_found
    end
  end

  describe "get_transaction/3" do
    test "returns not existing transation" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      {updated_block, _new_trie} =
        Blockchain.Block.put_transaction(
          %Blockchain.Block{},
          6,
          %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3},
          trie
        )

      result = Blockchain.Block.get_transaction(updated_block, 7, trie.db)

      assert is_nil(result)
    end

    test "returns the last transaction in a block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      transaction = %Blockchain.Transaction{
        data: "",
        gas_limit: 100_000,
        gas_price: 3,
        init: <<96, 3, 96, 5, 1, 96, 0, 82, 96, 0, 96, 32, 243>>,
        nonce: 5,
        r:
          110_274_197_540_583_527_170_567_040_609_004_947_678_532_096_020_311_055_824_363_076_718_114_581_104_395,
        s:
          15_165_203_061_950_746_568_488_278_734_700_551_064_641_299_899_120_962_819_352_765_267_479_743_108_366,
        to: "",
        v: 27,
        value: 5
      }

      {block, _updated_trie} =
        Blockchain.Block.put_transaction(%Blockchain.Block{}, 6, transaction, trie)

      result = Blockchain.Block.get_transaction(block, 6, trie.db)

      assert result == transaction
    end

    test "returns the first transaction in a block" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      transaction1 = %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}
      transaction2 = %Blockchain.Transaction{nonce: 2, v: 1, r: 2, s: 3}

      {updated_block, new_trie} =
        Blockchain.Block.put_transaction(%Blockchain.Block{}, 0, transaction1, trie)

      {updated_block, new_trie} =
        Blockchain.Block.put_transaction(
          updated_block,
          1,
          transaction2,
          new_trie
        )

      result = Blockchain.Block.get_transaction(updated_block, 0, new_trie.db)

      assert result == transaction1
    end
  end

  describe "put_block/3" do
    test "puts block with additional info" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      block = %Block{
        header: %Header{
          parent_hash: <<1::256>>,
          ommers_hash: <<2::256>>,
          beneficiary: <<3::160>>,
          state_root: <<4::256>>,
          transactions_root: <<5::256>>,
          receipts_root: <<6::256>>,
          logs_bloom: <<>>,
          difficulty: 5,
          number: 1,
          gas_limit: 5,
          gas_used: 3,
          timestamp: 6,
          extra_data: "",
          mix_hash: <<7::256>>,
          nonce: <<8::64>>
        },
        transactions: [],
        ommers: []
      }

      {:ok, {hash, updated_trie}} = Block.put_block(block, trie)
      {:ok, found_block} = Block.get_block(hash, updated_trie)

      assert found_block.header.size ==
               block |> Block.serialize() |> ExRLP.encode() |> byte_size()

      assert found_block.header.total_difficulty == block.header.difficulty
    end

    test "stores block with transaction locations" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
      transaction1 = %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}
      transaction2 = %Blockchain.Transaction{nonce: 2, v: 1, r: 2, s: 3}

      transactions = [transaction1, transaction2]

      block = %Block{
        header: %Header{
          parent_hash: <<1::256>>,
          ommers_hash: <<2::256>>,
          beneficiary: <<3::160>>,
          state_root: <<4::256>>,
          transactions_root: <<5::256>>,
          receipts_root: <<6::256>>,
          logs_bloom: <<>>,
          difficulty: 5,
          number: 1,
          gas_limit: 5,
          gas_used: 3,
          timestamp: 6,
          extra_data: "",
          mix_hash: <<7::256>>,
          nonce: <<8::64>>
        },
        transactions: transactions,
        ommers: []
      }

      {:ok, {_hash, updated_trie}} = Block.put_block(block, trie)

      transaction_hash1 = Signature.transaction_hash(transaction1)
      found_transaction1 = Block.get_transaction_by_hash(transaction_hash1, updated_trie)

      assert found_transaction1 == transaction1

      transaction_hash2 = Signature.transaction_hash(transaction2)
      found_transaction2 = Block.get_transaction_by_hash(transaction_hash2, updated_trie)

      assert found_transaction2 == transaction2
    end
  end

  describe "get_receipt_by_transaction_hash/2" do
    test "gets receipt" do
      trie = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())

      receipt1 =
        Receipt.new(
          <<47, 105, 125, 103, 30, 154, 228, 238, 36, 164, 60, 75, 13, 126, 21, 241, 203, 75, 166,
            222, 21, 97, 18, 13, 67, 185, 164, 232, 196, 168, 166, 238>>,
          265_390,
          [
            %EVM.LogEntry{
              address:
                <<220, 244, 33, 208, 147, 66, 139, 9, 108, 165, 1, 167, 205, 26, 116, 8, 85, 167,
                  151, 111>>,
              data:
                <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                  0, 0, 0, 0, 0>>,
              topics: []
            }
          ]
        )

      receipt2 =
        Receipt.new(
          <<74, 105, 125, 103, 30, 154, 228, 238, 36, 164, 60, 75, 13, 126, 21, 241, 203, 75, 166,
            222, 21, 97, 18, 13, 67, 185, 164, 232, 196, 168, 166, 238>>,
          2_653_911,
          [
            %EVM.LogEntry{
              address:
                <<220, 244, 33, 208, 147, 66, 139, 9, 108, 165, 1, 167, 205, 26, 116, 8, 85, 167,
                  151, 111>>,
              data:
                <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                  0, 0, 0, 0, 0>>,
              topics: []
            }
          ]
        )

      receipts = [receipt1, receipt2]

      transaction1 = %Blockchain.Transaction{nonce: 1, v: 1, r: 2, s: 3}
      transaction2 = %Blockchain.Transaction{nonce: 2, v: 1, r: 2, s: 3}
      transactions = [transaction1, transaction2]

      block = %Block{
        header: %Header{
          parent_hash: <<1::256>>,
          ommers_hash: <<2::256>>,
          beneficiary: <<3::160>>,
          state_root: <<4::256>>,
          transactions_root: <<5::256>>,
          receipts_root: <<6::256>>,
          logs_bloom: <<>>,
          difficulty: 5,
          number: 1,
          gas_limit: 5,
          gas_used: 3,
          timestamp: 6,
          extra_data: "",
          mix_hash: <<7::256>>,
          nonce: <<8::64>>
        },
        transactions: transactions,
        ommers: [],
        receipts: receipts
      }

      {:ok, {_hash, updated_trie}} = Block.put_block(block, trie)

      {found_receipt1, found_transaction1, _block} =
        transaction1
        |> Signature.transaction_hash()
        |> Block.get_receipt_by_transaction_hash(updated_trie)

      assert found_receipt1 == receipt1
      assert found_transaction1 == transaction1

      {found_receipt2, found_transaction2, _block} =
        transaction2
        |> Signature.transaction_hash()
        |> Block.get_receipt_by_transaction_hash(updated_trie)

      assert found_receipt2 == receipt2
      assert found_transaction2 == transaction2
    end
  end

  defp put_header(block, key, value) do
    new_header = Map.put(block.header, key, value)
    %{block | header: new_header}
  end
end
