defmodule JSONRPC2.ManaHandlerTest do
  use ExUnit.Case, async: true

  alias JSONRPC2.BridgeSyncMock
  alias JSONRPC2.SpecHandler
  alias JSONRPC2.TestFactory

  setup_all do
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

  describe "eth_getBlockByNumber" do
    test "fetches block by number" do
      block =
        TestFactory.build(:block,
          block_hash: <<0x2::256>>,
          header: TestFactory.build(:header, number: 10)
        )
        
      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": [10, false], "id": 71}),
        ~s({"id":71,"jsonrpc":"2.0","result":{"difficulty":"0x01","extraData":"","gasLimit":"0x00","gasUsed":"0x00","hash":"0x0000000000000000000000000000000000000000000000000000000000000002","logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","miner":"0x0000000000000000000000000000000000000010","nonce":"0x0000000000000000","number":"0x0a","parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010","receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010","size":"0x01f5","stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","timestamp":"0x01","totalDifficulty":"0x01","transactions":[],"transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","uncles":[]}})
      )
    end

    test "fetches block by number with full transactions" do
      transactions = [build(:transaction), build(:transaction)]

      block =
        build(:block,
          block_hash: <<7::256>>,
          transactions: transactions,
          header: build(:header, number: 11)
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": [11, true], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x01", "extraData":"", "gasLimit":"0x00", "gasUsed":"0x00", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "number":"0x0b", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "size":"0x028c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x01", "totalDifficulty":"0x01", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "hash":"0x0000000000000000000000000000000000000000000000000000000000000007", "transactions":[{"from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "input":"0x01", "nonce":"0x05", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000007", "blockNumber":"0x0b"}, {"from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "input":"0x01", "nonce":"0x05", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000007", "blockNumber":"0x0b"}]}})
      )
    end

    test "fetches block by number with transaction hashes" do
      transactions = [build(:transaction), build(:transaction)]

      block =
        build(:block,
          block_hash: <<8::256>>,
          transactions: transactions,
          header: build(:header, number: 12)
        )

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByNumber", "params": [12, false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x01", "extraData":"", "gasLimit":"0x00", "gasUsed":"0x00", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "size":"0x028c", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x01", "totalDifficulty":"0x01", "transactions":["0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08"], "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "hash":"0x0000000000000000000000000000000000000000000000000000000000000008", "number":"0x0c"}})
      )
    end
  end

  describe "eth_getBlockByHash" do
    test "fetches block by hash" do
      block = TestFactory.build(:block, block_hash: <<100::256>>)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["0x0000000000000000000000000000000000000000000000000000000000000064", false], "id": 71}),
        ~s({"id":71,"jsonrpc":"2.0","result":{"difficulty":"0x01","extraData":"","gasLimit":"0x00","gasUsed":"0x00","hash":"0x0000000000000000000000000000000000000000000000000000000000000064","logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","miner":"0x0000000000000000000000000000000000000010","nonce":"0x0000000000000000","number":"0x01","parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010","receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010","size":"0x01f5","stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","timestamp":"0x01","totalDifficulty":"0x01","transactions":[],"transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421","uncles":[]}})
      )
    end

    test "fetches block by hash with full transactions" do
      transactions = [build(:transaction), build(:transaction)]
      block = build(:block, block_hash: <<5::256>>, transactions: transactions)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["0x0000000000000000000000000000000000000000000000000000000000000005", true], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x01", "extraData":"", "gasLimit":"0x00", "gasUsed":"0x00", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "number":"0x01", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x01", "totalDifficulty":"0x01", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "hash":"0x0000000000000000000000000000000000000000000000000000000000000005", "size":"0x028c", "transactions":[{"blockHash":"0x0000000000000000000000000000000000000000000000000000000000000005", "blockNumber":"0x01", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "input":"0x01", "nonce":"0x05", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05"}, {"blockHash":"0x0000000000000000000000000000000000000000000000000000000000000005", "blockNumber":"0x01", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "input":"0x01", "nonce":"0x05", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05"}]}})
      )
    end

    test "fetches block by hash with transaction hashes" do
      transactions = [build(:transaction), build(:transaction)]
      block = build(:block, block_hash: <<6::256>>, transactions: transactions)

      :ok = BridgeSyncMock.put_block(block)

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getBlockByHash", "params": ["0x0000000000000000000000000000000000000000000000000000000000000006", false], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"difficulty":"0x01", "extraData":"", "gasLimit":"0x00", "gasUsed":"0x00", "logsBloom":"0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", "miner":"0x0000000000000000000000000000000000000010", "nonce":"0x0000000000000000", "number":"0x01", "parentHash":"0x0000000000000000000000000000000000000000000000000000000000000010", "receiptsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "sha3Uncles":"0x0000000000000000000000000000000000000000000000000000000000000010", "stateRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "timestamp":"0x01", "totalDifficulty":"0x01", "transactionsRoot":"0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421", "uncles":[], "hash":"0x0000000000000000000000000000000000000000000000000000000000000006", "size":"0x028c", "transactions":["0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08"]}})
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
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionByBlockHashAndIndex", "params": ["0x0000000000000000000000000000000000000000000000000000000000000003", "0x00"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "nonce":"0x05", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000003", "blockNumber":"0x01", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "input":"0x01", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05"}})
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

      assert_rpc_reply(
        SpecHandler,
        ~s({"jsonrpc": "2.0", "method": "eth_getTransactionByBlockNumberAndIndex", "params": [99, "0x00"], "id": 71}),
        ~s({"id":71, "jsonrpc":"2.0", "result":{"hash":"0x71024c28d1404f5d5fe3458b71b02d799f6d6aba29e285857732c0d06ebf3b08", "nonce":"0x05", "blockHash":"0x0000000000000000000000000000000000000000000000000000000000000003", "blockNumber":"0x63", "from":"0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a", "gas":"0x07", "gasPrice":"0x06", "input":"0x01", "r":"0x55fa77ee62e6c42e83b4f868c1e41643e45fd6f02a381a663318884751cb690a", "s":"0x7bd63c407cea7d619d598fb5766980ab8497b1b11c26d8bc59a132af96317793", "to":"0x", "transactionIndex":"0x00", "v":"0x1b", "value":"0x05"}})
      )
    end
  end

  defp assert_rpc_reply(handler, call, expected_reply) do
    assert {:reply, reply} = handler.handle(call)

    assert Jason.decode(reply) == Jason.decode(expected_reply)
  end
end
