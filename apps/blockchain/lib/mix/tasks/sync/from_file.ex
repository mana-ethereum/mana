defmodule Mix.Tasks.Sync.FromFile do
  @shortdoc "Allows users to sync the blockchain from a file exported by parity"
  @moduledoc """
  SyncFromFile allows users to sync the blockchain from a file exported by parity.

  You can make an export with the following command:

  `parity export blocks ./export-blocks-mainnet.bin`

  And then run `sync_with_file` to verify the chain:

  `mix run apps/blockchain/scripts/sync_from_file.ex export-blocks-mainnet.bin`
  """
  use Mix.Task
  require Logger

  def run(args) do
    {db, chain} = setup()

    current_block_number =
      case MerklePatriciaTree.DB.get(db, "current_block_number") do
        {:ok, current_block_number} ->
          current_block_number

        _ ->
          0
      end

    tree =
      case MerklePatriciaTree.DB.get(db, "current_block_tree") do
        {:ok, current_block_tree} ->
          :erlang.binary_to_term(current_block_tree)

        _ ->
          Blockchain.Blocktree.new_tree()
      end

    {first_block_data, blocks_data} =
      args
      |> File.read!()
      |> ExRLP.decode()
      |> Enum.split(3)

    first_block = Blockchain.Block.deserialize(first_block_data)

    blocks =
      [Blockchain.Genesis.create_block(chain, db), first_block] ++
        (blocks_data
         |> Enum.map(&Blockchain.Block.deserialize/1))

    add_block_to_tree(db, chain, tree, blocks, current_block_number)
  end

  def setup() do
    db = MerklePatriciaTree.DB.RocksDB.init(db_name())
    chain = Blockchain.Chain.load_chain(:foundation)

    {db, chain}
  end

  def add_block_to_tree(db, chain, tree, blocks, n) do
    next_block = Enum.at(blocks, n)

    if is_nil(next_block) do
      :ok = Logger.info("Validation complete")
      MerklePatriciaTree.DB.put!(db, "current_block_number", 0)
    else
      case Blockchain.Blocktree.verify_and_add_block(tree, chain, next_block, db) do
        {:ok, next_tree} ->
          :ok = Logger.info("Verified Block #{n}")
          MerklePatriciaTree.DB.put!(db, "current_block_number", next_block.header.number)
          add_block_to_tree(db, chain, next_tree, blocks, n + 1)

        {:invalid, error} ->
          :ok = Logger.info("Failed to Verify Block #{n}")
          _ = Logger.error(inspect(error))
          MerklePatriciaTree.DB.put!(db, "current_block_tree", :erlang.term_to_binary(tree))
      end
    end
  end

  defp db_name() do
    env = Mix.env() |> to_string()
    'db/mana-' ++ env
  end
end
