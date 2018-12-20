defmodule JSONRPC2.BridgeSyncMock do
  alias Blockchain.Account
  alias Blockchain.Block
  alias JSONRPC2.Response.Block, as: ResponseBlock
  alias JSONRPC2.Response.Receipt, as: ResponseReceipt
  alias JSONRPC2.Response.Transaction, as: ResponseTransaction
  alias JSONRPC2.Struct.EthSyncing
  alias MerklePatriciaTree.TrieStorage

  use GenServer

  def connected_peer_count() do
    GenServer.call(__MODULE__, :connected_peer_count)
  end

  def set_trie(trie) do
    GenServer.call(__MODULE__, {:set_trie, trie})
  end

  def get_trie do
    GenServer.call(__MODULE__, :get_trie)
  end

  def set_connected_peer_count(connected_peer_count) do
    GenServer.call(__MODULE__, {:set_connected_peer_count, connected_peer_count})
  end

  def set_starting_block_number(block_number) do
    GenServer.call(__MODULE__, {:set_starting_block_number, block_number})
  end

  def set_highest_block_number(block_number) do
    GenServer.call(__MODULE__, {:set_highest_block_number, block_number})
  end

  def get_code(address, block_number) do
    GenServer.call(__MODULE__, {:get_code, address, block_number})
  end

  def get_transaction_receipt(transaction_hash) do
    GenServer.call(__MODULE__, {:get_transaction_receipt, transaction_hash})
  end

  def get_balance(address, block_number) do
    GenServer.call(__MODULE__, {:get_balance, address, block_number})
  end

  def get_starting_block_number do
    GenServer.call(__MODULE__, :get_starting_block_number)
  end

  def get_highest_block_number do
    GenServer.call(__MODULE__, :get_highest_block_number)
  end

  def get_last_sync_block_stats() do
    GenServer.call(__MODULE__, :get_last_sync_block_stats)
  end

  def set_last_sync_block_stats(block_stats) do
    GenServer.call(__MODULE__, {:set_last_sync_block_stats, block_stats})
  end

  def put_block(block) do
    GenServer.call(__MODULE__, {:put_block, block})
  end

  def get_block_by_number(number, include_full_transactions) do
    GenServer.call(__MODULE__, {:get_block_by_number, number, include_full_transactions})
  end

  def get_block_by_hash(hash, include_full_transactions) do
    GenServer.call(__MODULE__, {:get_block_by_hash, hash, include_full_transactions})
  end

  def get_transaction_by_block_hash_and_index(block_hash, index) do
    GenServer.call(__MODULE__, {:get_transaction_by_block_hash_and_index, block_hash, index})
  end

  def get_transaction_by_block_number_and_index(block_hash, index) do
    GenServer.call(__MODULE__, {:get_transaction_by_block_number_and_index, block_hash, index})
  end

  def get_block_transaction_count_by_hash(block_hash) do
    GenServer.call(__MODULE__, {:get_block_transaction_count_by_hash, block_hash})
  end

  def get_block_transaction_count_by_number(block_number) do
    GenServer.call(__MODULE__, {:get_block_transaction_count_by_number, block_number})
  end

  def get_uncle_count_by_block_hash(block_hash) do
    GenServer.call(__MODULE__, {:get_uncle_count_by_block_hash, block_hash})
  end

  def get_uncle_count_by_block_number(block_number) do
    GenServer.call(__MODULE__, {:get_uncle_count_by_block_number, block_number})
  end

  def get_uncle_by_block_hash_and_index(block_hash, index) do
    GenServer.call(__MODULE__, {:get_uncle_by_block_and_index, {block_hash, index}})
  end

  def get_uncle_by_block_number_and_index(block_number, index) do
    GenServer.call(__MODULE__, {:get_uncle_by_block_and_index, {block_number, index}})
  end

  def get_transaction_by_hash(transaction_hash) do
    GenServer.call(__MODULE__, {:get_transaction_by_hash, transaction_hash})
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:connected_peer_count, _, state) do
    {:reply, state.connected_peer_count, state}
  end

  def handle_call(:get_highest_block_number, _, state) do
    {:reply, Map.get(state, :highest_block_number, 0), state}
  end

  def handle_call(:get_starting_block_number, _, state) do
    {:reply, Map.get(state, :starting_block_number, 0), state}
  end

  def handle_call({:set_trie, trie}, _, state) do
    {:reply, :ok, Map.put(state, :trie, trie)}
  end

  def handle_call(:get_trie, _, state) do
    {:reply, state.trie, state}
  end

  def handle_call({:set_connected_peer_count, connected_peer_count}, _, state) do
    {:reply, :ok, Map.put(state, :connected_peer_count, connected_peer_count)}
  end

  def handle_call({:set_highest_block_number, block_number}, _, state) do
    {:reply, :ok, Map.put(state, :highest_block_number, block_number)}
  end

  def handle_call({:set_starting_block_number, block_number}, _, state) do
    {:reply, :ok, Map.put(state, :set_starting_block_number, block_number)}
  end

  def handle_call({:put_block, block}, _, state = %{trie: trie}) do
    {:ok, {_, updated_trie}} = Block.put_block(block, trie, block.block_hash)
    updated_state = %{state | trie: updated_trie}

    {:reply, :ok, updated_state}
  end

  def handle_call(
        {:get_block_by_number, number, include_full_transactions},
        _,
        state = %{trie: trie}
      ) do
    block =
      case Block.get_block(number, trie) do
        {:ok, block} -> ResponseBlock.new(block, include_full_transactions)
        _ -> nil
      end

    {:reply, block, state}
  end

  def handle_call({:get_block_by_hash, hash, include_full_transactions}, _, state = %{trie: trie}) do
    block =
      case Block.get_block(hash, trie) do
        {:ok, block} -> ResponseBlock.new(block, include_full_transactions)
        _ -> nil
      end

    {:reply, block, state}
  end

  def handle_call(
        {:get_transaction_by_block_hash_and_index, block_hash, trx_index},
        _,
        state = %{trie: trie}
      ) do
    result =
      with {:ok, block} <- Block.get_block(block_hash, trie) do
        case Enum.at(block.transactions, trx_index) do
          nil -> nil
          transaction -> ResponseTransaction.new(transaction, block)
        end
      else
        _ -> nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_transaction_by_block_number_and_index, block_number, trx_index},
        _,
        state = %{trie: trie}
      ) do
    result =
      with {:ok, block} <- Block.get_block(block_number, trie) do
        case Enum.at(block.transactions, trx_index) do
          nil -> nil
          transaction -> ResponseTransaction.new(transaction, block)
        end
      else
        _ -> nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_block_transaction_count_by_hash, block_hash},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_hash, trie) do
        {:ok, block} ->
          block.transactions
          |> Enum.count()
          |> Exth.encode_unsigned_hex()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_block_transaction_count_by_number, block_number},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block.transactions
          |> Enum.count()
          |> Exth.encode_unsigned_hex()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_uncle_count_by_block_hash, block_hash},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_hash, trie) do
        {:ok, block} ->
          block.ommers
          |> Enum.count()
          |> Exth.encode_unsigned_hex()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_uncle_count_by_block_number, block_number},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block.ommers
          |> Enum.count()
          |> Exth.encode_unsigned_hex()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_uncle_by_block_and_index, {block_hash_or_index, index}},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_hash_or_index, trie) do
        {:ok, block} ->
          case Enum.at(block.ommers, index) do
            nil ->
              nil

            ommer_header ->
              uncle_block = %Block{header: ommer_header, transactions: [], ommers: []}

              uncle_block
              |> Block.add_metadata(trie)
              |> ResponseBlock.new()
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_code, address, block_number}, _, state = %{trie: trie}) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.machine_code(block_state, address) do
            {:ok, code} -> Exth.encode_hex(code)
            _ -> nil
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_balance, address, block_number}, _, state = %{trie: trie}) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.get_account(block_state, address) do
            nil ->
              nil

            account ->
              Exth.encode_unsigned_hex(account.balance)
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_transaction_by_hash, transaction_hash}, _, state = %{trie: trie}) do
    result =
      case Block.get_transaction_by_hash(transaction_hash, trie, true) do
        {transaction, block} -> ResponseTransaction.new(transaction, block)
        nil -> nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_transaction_receipt, transaction_hash}, _, state = %{trie: trie}) do
    result =
      case Block.get_receipt_by_transaction_hash(transaction_hash, trie) do
        {receipt, transaction, block} -> ResponseReceipt.new(receipt, transaction, block)
        _ -> nil
      end

    {:reply, result, state}
  end

  @spec handle_call(:get_last_sync_block_stats, {pid, any}, map()) ::
          {:reply, EthSyncing.output(), map()}
  def handle_call(:get_last_sync_block_stats, _, state) do
    {:reply, state.block_stats, state}
  end

  @spec handle_call(
          {:set_last_sync_block_stats, EthSyncing.input()},
          {pid, any},
          map()
        ) :: {:reply, :ok, map()}
  def handle_call({:set_last_sync_block_stats, block_stats}, _, state) do
    new_state = Map.put(state, :block_stats, block_stats)
    {:reply, :ok, new_state}
  end
end
