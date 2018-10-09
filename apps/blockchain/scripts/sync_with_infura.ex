require Logger

defmodule SyncWithInfura do
  @save_block_interval 1000
  require Logger

  def setup() do
    db = MerklePatriciaTree.DB.RocksDB.init(db_name())
    chain = Blockchain.Chain.load_chain(:foundation)

    {db, chain}
  end

  def add_block_to_tree(db, chain, tree, n) do
    next_block = get_block(n)

    if rem(n, @save_block_interval) == 0 do
      Logger.info("Saved progress at block #{n}")
      MerklePatriciaTree.DB.put!(db, "current_block_hash", Blockchain.Block.hash(next_block))
      MerklePatriciaTree.DB.put!(db, "current_block_tree", :erlang.term_to_binary(tree))
    end

    case Blockchain.Blocktree.verify_and_add_block(tree, chain, next_block, db) do
      {:ok, next_tree} ->
        add_block_to_tree(db, chain, next_tree, n + 1)

      {:invalid, error} ->
        Logger.info("Failed to Verify Block #{n}")
        Logger.error(inspect(error))
    end
  end

  def load_hex("0x" <> hex_string) do
    padded_hex_string =
      if rem(byte_size(hex_string), 2) == 1, do: "0" <> hex_string, else: hex_string

    {:ok, hex} = Base.decode16(padded_hex_string, case: :lower)

    hex
  end

  def get_block(n) do
    {:ok, b} = Ethereumex.IpcClient.eth_get_block_by_number(to_hex(n), true)

    block = %Blockchain.Block{
      block_hash: b["hash"] |> load_hex(),
      header: %Block.Header{
        parent_hash: b["parentHash"] |> load_hex(),
        ommers_hash: b["sha3Uncles"] |> load_hex(),
        beneficiary: b["miner"] |> load_hex(),
        state_root: b["stateRoot"] |> load_hex(),
        transactions_root: b["transactionsRoot"] |> load_hex(),
        receipts_root: b["receiptsRoot"] |> load_hex(),
        logs_bloom: b["logsBloom"] |> load_hex(),
        difficulty: b["difficulty"] |> load_hex() |> :binary.decode_unsigned(),
        number: b["number"] |> load_hex() |> :binary.decode_unsigned(),
        gas_limit: b["gasLimit"] |> load_hex() |> :binary.decode_unsigned(),
        gas_used: b["gasUsed"] |> load_hex() |> :binary.decode_unsigned(),
        timestamp: b["timestamp"] |> load_hex() |> :binary.decode_unsigned(),
        extra_data: b["extraData"] |> load_hex(),
        mix_hash: b["mixHash"] |> load_hex(),
        nonce: b["nonce"] |> load_hex()
      },
      transactions:
        for trx <- b["transactions"] do
          %Blockchain.Transaction{
            nonce: trx["nonce"] |> load_hex() |> :binary.decode_unsigned(),
            gas_price: trx["gasPrice"] |> load_hex() |> :binary.decode_unsigned(),
            gas_limit: trx["gas"] |> load_hex() |> :binary.decode_unsigned(),
            to: if(trx["to"], do: trx["to"] |> load_hex(), else: <<>>),
            value: trx["value"] |> load_hex() |> :binary.decode_unsigned(),
            v: trx["v"] |> load_hex() |> :binary.decode_unsigned(),
            r: trx["r"] |> load_hex() |> :binary.decode_unsigned(),
            s: trx["s"] |> load_hex() |> :binary.decode_unsigned(),
            init: if(trx["to"] |> is_nil, do: trx["input"] |> load_hex(), else: <<>>),
            data: if(trx["to"], do: trx["input"] |> load_hex(), else: <<>>)
          }
        end,
      ommers: []
    }

    ommers =
      for {_ommer_hash, index} <- Stream.with_index(b["uncles"]) do
        {:ok, ommer} =
          Ethereumex.IpcClient.eth_get_uncle_by_block_hash_and_index(b["hash"], to_hex(index))

        %Block.Header{
          parent_hash: ommer["parentHash"] |> load_hex(),
          ommers_hash: ommer["sha3Uncles"] |> load_hex(),
          beneficiary: ommer["miner"] |> load_hex(),
          state_root: ommer["stateRoot"] |> load_hex(),
          transactions_root: ommer["transactionsRoot"] |> load_hex(),
          receipts_root: ommer["receiptsRoot"] |> load_hex(),
          logs_bloom: ommer["logsBloom"] |> load_hex(),
          difficulty: ommer["difficulty"] |> load_hex() |> :binary.decode_unsigned(),
          number: ommer["number"] |> load_hex() |> :binary.decode_unsigned(),
          gas_limit: ommer["gasLimit"] |> load_hex() |> :binary.decode_unsigned(),
          gas_used: ommer["gasUsed"] |> load_hex() |> :binary.decode_unsigned(),
          timestamp: ommer["timestamp"] |> load_hex() |> :binary.decode_unsigned(),
          extra_data: ommer["extraData"] |> load_hex(),
          mix_hash: ommer["mixHash"] |> load_hex(),
          nonce: ommer["nonce"] |> load_hex()
        }
      end

    Blockchain.Block.add_ommers(block, ommers)
  rescue
    error ->
      Logger.info("error:  #{inspect(error)}")
      Logger.info("Retrying")
      get_block(n)
  end

  def to_hex(n) do
    if n == 0 do
      "0x0"
    else
      "0x#{String.trim_leading(Base.encode16(:binary.encode_unsigned(n)), "0")}"
    end
  end

  defp db_name() do
    env = Mix.env() |> to_string()
    "db/mana-" <> env
  end

  def get_parents(block, db, parents) do
    case Blockchain.Block.get_parent_block(block, db) do
      :genesis -> parents
      {:ok, parent} -> get_parents(parent, db, [parent | parents])
    end
  end
end

{db, chain} = SyncWithInfura.setup()

current_block =
  case MerklePatriciaTree.DB.get(db, "current_block_hash") do
    {:ok, current_block_hash} ->
      {:ok, current_block} = Blockchain.Block.get_block(current_block_hash, db)
      current_block

    _ ->
      Blockchain.Genesis.create_block(chain, db)
  end

tree =
  case MerklePatriciaTree.DB.get(db, "current_block_tree") do
    {:ok, current_block_tree} ->
      :erlang.binary_to_term(current_block_tree)

    _ ->
      Blockchain.Blocktree.new_tree()
  end

SyncWithInfura.add_block_to_tree(db, chain, tree, current_block.header.number)
