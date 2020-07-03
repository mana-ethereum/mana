defmodule JSONRPC2.ManaHandlerTest do
  use ExUnit.Case, async: true

  alias Blockchain.Account
  alias Blockchain.Transaction.Signature
  alias ExthCrypto.Hash.Keccak
  alias JSONRPC2.BridgeSyncMock
  alias JSONRPC2.SpecHandler
  alias JSONRPC2.TestFactory
  alias MerklePatriciaTree.TrieStorage

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()
    trie = MerklePatriciaTree.Trie.new(db)
    state = %{trie: trie}

    {:ok, pid} = BridgeSyncMock.start_link(state)
    {:ok, %{pid: pid}}
  end

  describe "is web3_clientVersion method behaving correctly when" do
    test "called without params" do
      version = Application.get_env(:jsonrpc2, :mana_version)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_clientVersion", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": "#{version}", "id": 1})
      )
    end
  end

  describe "is web3sha method behaving correctly when" do
    test "empty address" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x00"], "id": 2}),
        ~s({"jsonrpc": "2.0", "result": "0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a", "id": 2})
      )
    end

    test "params that are not base16" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x68656c6c6f20776f726c6"], "id": 2}),
        ~s({"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 2})
      )
    end

    test "params that are base16" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "web3_sha3", "params": ["0x68656c6c6f20776f726c64"], "id": 5}),
        ~s({"jsonrpc": "2.0", "result": "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad", "id": 5})
      )
    end
  end

  describe "is net_version method behaving correctly when" do
    test "called without params" do
      network_id = Application.get_env(:ex_wire, :network_id)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_version", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": "#{network_id}", "id": 1})
      )
    end
  end

  describe "is net_listening method behaving correctly when" do
    test "called without params" do
      discovery = Application.get_env(:ex_wire, :discovery)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_listening", "params": [], "id": 1}),
        ~s({"jsonrpc": "2.0", "result": #{discovery}, "id": 1})
      )
    end
  end

  describe "is net_peerCount method behaving correctly when" do
    test "called without params for 0 peers", %{pid: _pid} do
      connected_peer_count = 0
      :ok = BridgeSyncMock.set_connected_peer_count(connected_peer_count)

      expected_result_count = "0x0"

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_peerCount", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": "#{expected_result_count}", "id": 74})
      )
    end

    test "called without params for 2 peers", %{pid: _pid} do
      connected_peer_count = 2
      :ok = BridgeSyncMock.set_connected_peer_count(connected_peer_count)

      expected_result_count = "0x2"

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "net_peerCount", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": "#{expected_result_count}", "id": 74})
      )
    end
  end

  describe "is eth_syncing method behaving correctly when" do
    test "all parameters are 0", %{pid: _pid} do
      :ok = BridgeSyncMock.set_last_sync_block_stats({0, 0, 0})

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 74}),
        ~s({"jsonrpc": "2.0", "result": {"currentBlock":"0x0","startingBlock":"0x0","highestBlock":"0x0"}, "id": 74})
      )
    end

    test "all parameters are above 0", %{pid: _pid} do
      :ok = BridgeSyncMock.set_last_sync_block_stats({900, 902, 1108})

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 71}),
        ~s({"jsonrpc": "2.0", "result": {"currentBlock":"0x384","startingBlock":"0x386", "highestBlock":"0x454"}, "id": 71})
      )
    end
  end

  describe "eth_blockNumber" do
    test "fetches current block number" do
      :ok = BridgeSyncMock.set_last_sync_block_stats({77, 88, 99})

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_blockNumber", "params": [], "id": 71}),
        ~s({"jsonrpc": "2.0", "result": "0x4d", "id": 71})
      )
    end
  end

  describe "eth_getBlockByNumber" do
    test "fetches block by number" do
      block = TestFactory.build(:block)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["#{
          encode_hex(block.header.number)
        }", false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "size":"0x1f5", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactions":[], "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "extraData":"0x", "hash":"0x0000000000000000000000000000000000000000000000000000000000000010", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010"}})
      )
    end

    test "fetches block by number with full transactions" do
      transactions = [TestFactory.build(:transaction), TestFactory.build(:transaction)]

      block =
        TestFactory.build(:block,
          transactions: transactions
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["#{
          encode_hex(block.header.number)
        }", true], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "extraData":"0x", "gasLimit":"0x0", "gasUsed":"0x0", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "size":"0x28c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "hash":"0x0000000000000000000000000000000000000000000000000000000000000010", "number":"0x1", "transactions":[{"from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "blockNumber":"0x1"}, {"from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "blockNumber":"0x1"}]}})
      )
    end

    test "fetches block by number with transaction hashes" do
      transactions = [TestFactory.build(:transaction), TestFactory.build(:transaction)]

      block =
        TestFactory.build(:block,
          transactions: transactions
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": ["#{
          encode_hex(block.header.number)
        }", false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "extraData":"0x", "gasLimit":"0x0", "gasUsed":"0x0", "hash":"0x0000000000000000000000000000000000000000000000000000000000000010", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "number":"0x1", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "size":"0x28c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "transactions":["0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b"]}})
      )
    end
  end

  describe "eth_getBlockByHash" do
    test "fetches block by hash" do
      block = TestFactory.build(:block)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["#{
          encode_hex(block.block_hash)
        }", false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "size":"0x1f5", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactions":[], "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "extraData":"0x", "hash":"0x0000000000000000000000000000000000000000000000000000000000000010", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010"}})
      )
    end

    test "fetches block by hash with full transactions" do
      transactions = [TestFactory.build(:transaction), TestFactory.build(:transaction)]
      block = TestFactory.build(:block, block_hash: <<5::256>>, transactions: transactions)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["#{
          encode_hex(block.block_hash)
        }", true], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "size":"0x28c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "extraData":"0x", "hash":"0x0000000000000000000000000000000000000000000000000000000000000005", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "transactions":[{"blockNumber":"0x1", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000005", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "to":"0x"}, {"blockNumber":"0x1", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000005", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "to":"0x"}]}})
      )
    end

    test "fetches block by hash with transaction hashes" do
      transactions = [TestFactory.build(:transaction), TestFactory.build(:transaction)]
      block = TestFactory.build(:block, block_hash: <<6::256>>, transactions: transactions)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["#{
          encode_hex(block.block_hash)
        }", false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x1", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "size":"0x28c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x1", "totalDifficulty":"0x1", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "extraData":"0x", "hash":"0x0000000000000000000000000000000000000000000000000000000000000006", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "transactions":["0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b"]}})
      )
    end
  end

  describe "eth_getTransactionByBlockHashAndIndex" do
    test "fetches transaction by block hash and index" do
      transaction = TestFactory.build(:transaction)
      block = TestFactory.build(:block, block_hash: <<0x3::256>>, transactions: [transaction])
      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionByBlockHashAndIndex", "params": ["#{
          encode_hex(block.block_hash)
        }", "0x00"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"blockNumber":"0x1", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000003", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "to":"0x"}})
      )
    end
  end

  describe "eth_getTransactionByBlockNumberAndIndex" do
    test "fetches transaction by block number and index" do
      transaction = TestFactory.build(:transaction)

      block =
        TestFactory.build(:block,
          block_hash: <<0x3::256>>,
          transactions: [transaction],
          header: TestFactory.build(:header, number: 99)
        )

      :ok = BridgeSyncMock.put_block(block)

      index = 0

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionByBlockNumberAndIndex", "params": ["#{
          encode_hex(block.header.number)
        }", "#{encode_hex(index)}"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"blockNumber":"0x63", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x7", "gasPrice":"0x6", "nonce":"0x5", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "transactionIndex":"0x0", "v":"0x1b", "value":"0x5", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000003", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "to":"0x"}})
      )
    end
  end

  describe "eth_getBlockTransactionCountByHash" do
    test "fetches transaction count by block hash" do
      transactions = [
        TestFactory.build(:transaction),
        TestFactory.build(:transaction),
        TestFactory.build(:transaction)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x101::256>>,
          transactions: transactions
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockTransactionCountByHash", "params": ["#{
          encode_hex(block.block_hash)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x3"})
      )
    end
  end

  describe "eth_getBlockTransactionCountByNumber" do
    test "fetches transaction count by block number" do
      transactions = [
        TestFactory.build(:transaction),
        TestFactory.build(:transaction),
        TestFactory.build(:transaction)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x102::256>>,
          transactions: transactions,
          header: TestFactory.build(:header, number: 1000)
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockTransactionCountByNumber", "params": ["#{
          encode_hex(block.header.number)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x3"})
      )
    end
  end

  describe "eth_getUncleCountByBlockHash" do
    test "fetches uncle count by block hash" do
      uncles = [
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x111::256>>,
          header: TestFactory.build(:header, number: 1000),
          ommers: uncles
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getUncleCountByBlockHash", "params": ["#{
          encode_hex(block.block_hash)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x4"})
      )
    end
  end

  describe "eth_getUncleCountByBlockNumber" do
    test "fetches uncle count by block number" do
      uncles = [
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x111::256>>,
          header: TestFactory.build(:header, number: 5000),
          ommers: uncles
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getUncleCountByBlockNumber", "params": ["#{
          encode_hex(block.header.number)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x4"})
      )
    end
  end

  describe "eth_getCode" do
    test "fetches account with empty code" do
      trie = BridgeSyncMock.get_trie()

      block =
        TestFactory.build(:block,
          block_hash: <<0x113::256>>,
          header: TestFactory.build(:header, number: 7000)
        )

      address = <<5::160>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: Account.empty_keccak()
      }

      trie_with_account =
        trie
        |> TrieStorage.set_root_hash(block.header.state_root)
        |> Account.put_account(address, account)

      updated_block = %{
        block
        | header: %{block.header | state_root: TrieStorage.root_hash(trie_with_account)}
      }

      :ok = BridgeSyncMock.put_block(updated_block)
      :ok = BridgeSyncMock.set_highest_block_number(updated_block.header.number)
      :ok = BridgeSyncMock.set_trie(trie_with_account)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getCode", "params": ["#{encode_hex(address)}", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x"})
      )
    end

    test "fetches account with not empty code" do
      trie = BridgeSyncMock.get_trie()

      block =
        TestFactory.build(:block,
          block_hash: <<0x114::256>>,
          header: TestFactory.build(:header, number: 7001)
        )

      address = <<6::160>>

      machine_code = <<1>>

      kec = Keccak.kec(machine_code)

      _ = TrieStorage.put_raw_key!(trie, kec, machine_code)

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: kec
      }

      trie_with_account =
        trie
        |> TrieStorage.set_root_hash(block.header.state_root)
        |> Account.put_account(address, account)

      updated_block = %{
        block
        | header: %{block.header | state_root: TrieStorage.root_hash(trie_with_account)}
      }

      :ok = BridgeSyncMock.put_block(updated_block)
      :ok = BridgeSyncMock.set_highest_block_number(updated_block.header.number)
      :ok = BridgeSyncMock.set_trie(trie_with_account)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getCode", "params": ["#{encode_hex(address)}", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x01"})
      )
    end
  end

  describe "eth_getBalance" do
    test "fetches balance of an existing account" do
      trie = BridgeSyncMock.get_trie()

      address = <<6::160>>

      block =
        TestFactory.build(:block,
          block_hash: <<0x119::256>>,
          header: TestFactory.build(:header, number: 7007)
        )

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: Account.empty_keccak()
      }

      trie_with_account =
        trie
        |> TrieStorage.set_root_hash(block.header.state_root)
        |> Account.put_account(address, account)

      updated_block = %{
        block
        | header: %{block.header | state_root: TrieStorage.root_hash(trie_with_account)}
      }

      :ok = BridgeSyncMock.put_block(updated_block)
      :ok = BridgeSyncMock.set_highest_block_number(updated_block.header.number)
      :ok = BridgeSyncMock.set_trie(trie_with_account)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["#{encode_hex(address)}", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0xa"})
      )
    end

    test "fetches balance of a nonexisting account" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBalance", "params": ["0x0000000000000000000000000000000000000011", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":null})
      )
    end
  end

  describe "eth_getTransactionByHash" do
    test "fetches transaction by hash" do
      transaction = TestFactory.build(:transaction)

      block = TestFactory.build(:block, block_hash: <<0x1AA1::256>>, transactions: [transaction])

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionByHash", "params": ["#{
          transaction_hash(transaction)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"blockHash":"0x0000000000000000000000000000000000000000000000000000000000001aa1", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "hash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "input":"0x01", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "v":"0x1b", "blockNumber":"0x1", "gas":"0x7", "gasPrice":"0x6", "nonce":"0x5", "transactionIndex":"0x0", "value":"0x5"}})
      )
    end
  end

  describe "eth_getTransactionReceipt" do
    test "fetch receipt by transaction hash" do
      transaction = TestFactory.build(:transaction)

      receipt = TestFactory.build(:receipt)

      block =
        TestFactory.build(:block,
          block_hash: <<0x1AAA::256>>,
          transactions: [transaction],
          receipts: [receipt]
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionReceipt", "params": ["#{
          transaction_hash(transaction)
        }"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"blockHash":"0x0000000000000000000000000000000000000000000000000000000000001aaa", "contractAddress":"0x2e07fda729826779d050aa629355211735ce350d", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "logs":[], "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "to":"0x", "transactionHash":"0x7f71d14c13c402ce13c6f063b83e085f097a878e33163d6146cece277936531b", "blockNumber":"0x1", "cumulativeGasUsed":"0x3e8", "gasUsed":"0x3e8", "status":"0x1", "transactionIndex":"0x0"}})
      )
    end
  end

  describe "eth_getUncleByBlockHashAndIndex" do
    test "fetches uncle by block hash and index" do
      uncles = [
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x113::256>>,
          header: TestFactory.build(:header, number: 1110),
          ommers: uncles
        )

      :ok = BridgeSyncMock.put_block(block)

      index = 3

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getUncleByBlockHashAndIndex", "params": ["#{
          encode_hex(block.block_hash)
        }", "#{encode_hex(index)}"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"hash":"0xa33912876669bdef5f8e9bcd54b32864c2cd6af57370f06dd17472942c5728a5", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "transactions":[], "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "difficulty":"0x1", "extraData":"0x", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "size":"0x1f5", "timestamp":"0x1", "totalDifficulty":"0x1"}})
      )
    end
  end

  describe "eth_getUncleByBlockNumberAndIndex" do
    test "fetches uncle by block hash and index" do
      uncles = [
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header),
        TestFactory.build(:header)
      ]

      block =
        TestFactory.build(:block,
          block_hash: <<0x119::256>>,
          header: TestFactory.build(:header, number: 1117),
          ommers: uncles
        )

      :ok = BridgeSyncMock.put_block(block)

      index = 3

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getUncleByBlockNumberAndIndex", "params": ["#{
          encode_hex(block.header.number)
        }", "#{encode_hex(index)}"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"hash":"0xa33912876669bdef5f8e9bcd54b32864c2cd6af57370f06dd17472942c5728a5", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "transactions":[], "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "difficulty":"0x1", "extraData":"0x", "gasLimit":"0x0", "gasUsed":"0x0", "number":"0x1", "size":"0x1f5", "timestamp":"0x1", "totalDifficulty":"0x1"}})
      )
    end

    test "failes when params are invalid" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getUncleByBlockNumberAndIndex", "params": ["wrong", "params"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "error":{"code":-32602, "message":"Invalid params"}})
      )
    end
  end

  describe "eth_getStorageAt" do
    test "gets value from the storage" do
      trie = BridgeSyncMock.get_trie()

      address = <<89::160>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: nil
      }

      key = 66
      value = 77

      state_with_storage =
        trie
        |> Account.put_account(address, account)
        |> Account.put_storage(address, key, value)

      block =
        TestFactory.build(:block,
          block_hash: <<0x11115::256>>,
          header:
            TestFactory.build(:header,
              number: 7091,
              state_root: TrieStorage.root_hash(state_with_storage)
            )
        )

      :ok = BridgeSyncMock.put_block(block)
      :ok = BridgeSyncMock.set_highest_block_number(block.header.number)
      :ok = BridgeSyncMock.set_trie(state_with_storage)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getStorageAt", "params": ["0x0000000000000000000000000000000000000059", "0x42", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x4d"})
      )
    end

    test "fetches value from the storage from an intermediate block" do
      trie = BridgeSyncMock.get_trie()

      address = <<89::160>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: nil
      }

      key = 66
      latest_value = 77

      latest_storage =
        trie
        |> Account.put_account(address, account)
        |> Account.put_storage(address, key, latest_value)

      block =
        TestFactory.build(:block,
          block_hash: <<0x111151::256>>,
          header:
            TestFactory.build(:header,
              number: 7181,
              state_root: TrieStorage.root_hash(latest_storage)
            )
        )

      :ok = BridgeSyncMock.put_block(block)
      :ok = BridgeSyncMock.set_highest_block_number(block.header.number)

      intermediate_value = 88

      intermediate_storage = Account.put_storage(latest_storage, address, key, intermediate_value)

      intermediate_block =
        TestFactory.build(:block,
          block_hash: <<0x1111511::256>>,
          header:
            TestFactory.build(:header,
              number: 7180,
              state_root: TrieStorage.root_hash(intermediate_storage)
            )
        )

      :ok = BridgeSyncMock.put_block(intermediate_block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getStorageAt", "params": ["0x0000000000000000000000000000000000000059", "0x42", "0x1c0c"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x58"})
      )
    end
  end

  describe "eth_getTransactionCount" do
    test "fetches transaction's nonce" do
      trie = BridgeSyncMock.get_trie()

      block =
        TestFactory.build(:block,
          block_hash: <<0x11398::256>>,
          header: TestFactory.build(:header, number: 7661)
        )

      address = <<5::160>>

      account = %Account{
        nonce: 5,
        balance: 10,
        storage_root: Account.empty_trie(),
        code_hash: Account.empty_keccak()
      }

      trie_with_account =
        trie
        |> TrieStorage.set_root_hash(block.header.state_root)
        |> Account.put_account(address, account)

      updated_block = %{
        block
        | header: %{block.header | state_root: TrieStorage.root_hash(trie_with_account)}
      }

      :ok = BridgeSyncMock.put_block(updated_block)
      :ok = BridgeSyncMock.set_highest_block_number(updated_block.header.number)
      :ok = BridgeSyncMock.set_trie(trie_with_account)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionCount", "params": ["0x0000000000000000000000000000000000000005", "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"0x5"})
      )
    end
  end

  describe "eth_estimateGas" do
    test "estimates gas" do
      block =
        TestFactory.build(:block, header: TestFactory.build(:header, gas_limit: 100_000_000))

      from_address = <<0x10::160>>
      from_account = TestFactory.build(:account, balance: 10_000_000)

      to_address = <<0x11::160>>
      to_account = TestFactory.build(:account)

      :ok = BridgeSyncMock.put_block(block)

      trie = BridgeSyncMock.get_trie()

      trie_with_accounts =
        trie
        |> Account.put_account(from_address, from_account)
        |> Account.put_account(to_address, to_account)

      :ok = BridgeSyncMock.put_block(block)
      :ok = BridgeSyncMock.set_highest_block_number(block.header.number)
      :ok = BridgeSyncMock.set_trie(trie_with_accounts)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_estimateGas", "params": [{"from": "#{
          encode_hex(from_address)
        }", "to": "#{encode_hex(to_address)}", "gas": "#{encode_hex(10_000)}", "gas_price": "#{
          encode_hex(1)
        }", "value": "#{encode_hex(1)}", "data": "#{encode_hex("")}"}, "latest"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":"#{encode_hex(21_000)}"})
      )
    end

    test "can't find block" do
      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_estimateGas", "params": [{}, "0x01"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result": {"error": "Block is not found"}})
      )
    end
  end

  defp assert_rpc_reply(handler, call, expected_reply) do
    assert {:reply, reply} = handler.handle(call)

    assert Jason.decode(reply) == Jason.decode(expected_reply)
  end

  defp encode_hex(binary) when is_binary(binary) do
    "0x" <> Base.encode16(binary, case: :lower)
  end

  defp encode_hex(number) when is_integer(number) do
    number
    |> :binary.encode_unsigned()
    |> encode_hex()
  end

  defp transaction_hash(transaction) do
    transaction
    |> Signature.transaction_hash()
    |> encode_hex()
  end
end
