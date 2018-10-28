defmodule CLI.Sync.RPC do
  @moduledoc """
  Script to set-up a sync with Infura.
  """
  require Logger

  @save_block_interval 1000
  @max_retries 5

  @type ethereumex_client :: module()
  @type state :: ethereumex_client()

  @provider_url "http://mainnet.infura.io"

  @doc """
  Sets up database and loads chain information
  """
  @spec setup(String.t() | nil) :: {:ok, state} | {:error, any()}
  def setup(provider_url) do
    provider_url = if provider_url, do: provider_url, else: @provider_url

    {:ok, _started} = Application.ensure_all_started(:ethereumex)

    state =
      case URI.parse(provider_url) do
        %URI{scheme: scheme} when scheme == "http" or scheme == "https" ->
          Application.put_env(:ethereumex, :url, provider_url)

          {:ok, Ethereumex.HttpClient}

        %URI{scheme: "ipc", path: ipc_path} ->
          Application.put_env(:ethereumex, :ipc_path, ipc_path)

          {:ok, Ethereumex.IpcClient}

        els ->
          {:error, "Unknown scheme for #{inspect(els)}"}
      end

    state
  end

  @doc """
  Adds a new block to the blocktree. 
  """
  @spec add_block_to_tree(
          state,
          MerklePatriciaTree.DB.t(),
          Blockchain.Chain.t(),
          Blockchain.Blocktree.t(),
          integer(),
          integer() | nil
        ) :: {:ok, Blockchain.Blocktree.t()} | {:error, any()}
  def add_block_to_tree(client, db, chain, tree, block_number, max_new_blocks \\ nil) do
    if !is_nil(max_new_blocks) && max_new_blocks > 0 do
      {:ok, tree}
    else
      {:ok, next_block} = get_block(block_number, client)

      case Blockchain.Blocktree.verify_and_add_block(tree, chain, next_block, db) do
        {:ok, next_tree} ->
          if rem(block_number, @save_block_interval) == 0 do
            Logger.info("Saved progress at block #{block_number}")

            MerklePatriciaTree.DB.put!(
              db,
              "current_block_tree",
              :erlang.term_to_binary(next_tree)
            )
          end

          add_block_to_tree(client, db, chain, next_tree, block_number + 1, max_new_blocks - 1)

        {:invalid, error} ->
          Logger.debug(fn -> "Failed block: #{inspect(next_block)}" end)
          Logger.error(fn -> "Failed to verify block #{block_number}: #{inspect(error)}" end)

          if tree.best_block do
            Logger.info(fn -> "Saving progress at block #{tree.best_block.header.number}" end)

            MerklePatriciaTree.DB.put!(db, "current_block_tree", :erlang.term_to_binary(tree))
          end

          {:error, error}
      end
    end
  end

  @spec get_block(integer(), ethereumex_client()) :: {:ok, Blockchain.Block.t()} | {:error, any()}
  def get_block(number, client) do
    with {:ok, block_data} <- load_new_block(number, client) do
      block = %Blockchain.Block{
        block_hash: get(block_data, "hash"),
        header: %Block.Header{
          parent_hash: get(block_data, "parentHash"),
          ommers_hash: get(block_data, "sha3Uncles"),
          beneficiary: get(block_data, "miner"),
          state_root: get(block_data, "stateRoot"),
          transactions_root: get(block_data, "transactionsRoot"),
          receipts_root: get(block_data, "receiptsRoot"),
          logs_bloom: get(block_data, "logsBloom"),
          difficulty: get(block_data, "difficulty", :integer),
          number: get(block_data, "number", :integer),
          gas_limit: get(block_data, "gasLimit", :integer),
          gas_used: get(block_data, "gasUsed", :integer),
          timestamp: get(block_data, "timestamp", :integer),
          extra_data: get(block_data, "extraData"),
          mix_hash: get(block_data, "mixHash"),
          nonce: get(block_data, "nonce")
        },
        transactions:
          for trx_data <- get(block_data, "transactions", :raw) do
            to = get(trx_data, "to", :binary, <<>>)
            input = get(trx_data, "input")

            %Blockchain.Transaction{
              nonce: get(trx_data, "nonce", :integer),
              gas_price: get(trx_data, "gasPrice", :integer),
              gas_limit: get(trx_data, "gas", :integer),
              to: to,
              value: get(trx_data, "value", :integer),
              v: get(trx_data, "v", :integer),
              r: get(trx_data, "r", :integer),
              s: get(trx_data, "s", :integer),
              init: if(to == <<>>, do: input, else: <<>>),
              data: if(to != <<>>, do: input, else: <<>>)
            }
          end,
        ommers: []
      }

      ommers_stream =
        block_data
        |> get("uncles", :raw)
        |> Stream.with_index()

      ommers =
        for {_ommer_hash, index} <- ommers_stream do
          {:ok, ommer_data} =
            client.eth_get_uncle_by_block_hash_and_index(
              get(block_data, "hash"),
              to_hex(index)
            )

          %Block.Header{
            parent_hash: get(ommer_data, "parentHash"),
            ommers_hash: get(ommer_data, "sha3Uncles"),
            beneficiary: get(ommer_data, "miner"),
            state_root: get(ommer_data, "stateRoot"),
            transactions_root: get(ommer_data, "transactionsRoot"),
            receipts_root: get(ommer_data, "receiptsRoot"),
            logs_bloom: get(ommer_data, "logsBloom"),
            difficulty: get(ommer_data, "difficulty", :integer),
            number: get(ommer_data, "number", :integer),
            gas_limit: get(ommer_data, "gasLimit", :integer),
            gas_used: get(ommer_data, "gasUsed", :integer),
            timestamp: get(ommer_data, "timestamp", :integer),
            extra_data: get(ommer_data, "extraData"),
            mix_hash: get(ommer_data, "mixHash"),
            nonce: get(ommer_data, "nonce")
          }
        end

      block_with_ommers = Blockchain.Block.add_ommers(block, ommers)

      {:ok, block_with_ommers}
    end
  end

  @spec load_new_block(integer(), ethereumex_client(), integer()) :: {:ok, %{}} | {:error, any()}
  defp load_new_block(number, client, retries \\ @max_retries) do
    case client.eth_get_block_by_number(to_hex(number), true) do
      {:ok, block} ->
        {:ok, block}

      {:error, error} ->
        if retries > 0 do
          Logger.info("Error loading block, retrying: #{inspect(error)}")
          load_new_block(number, client, retries - 1)
        else
          {:error, error}
        end
    end
  end

  @spec to_hex(integer()) :: String.t()
  defp to_hex(n) do
    if n == 0 do
      "0x0"
    else
      "0x#{String.trim_leading(Base.encode16(:binary.encode_unsigned(n)), "0")}"
    end
  end

  @spec load_hex(String.t()) :: binary()
  defp load_hex("0x" <> hex_string) do
    padded_hex_string =
      if rem(byte_size(hex_string), 2) == 1, do: "0" <> hex_string, else: hex_string

    {:ok, hex} = Base.decode16(padded_hex_string, case: :lower)

    hex
  end

  @spec get(%{}, String.t(), atom(), nil | binary() | integer()) :: binary() | integer() | %{}
  defp get(map, key, type \\ :binary, default \\ nil) do
    case Map.get(map, key) do
      nil ->
        default

      value ->
        case type do
          :binary when is_binary(value) ->
            load_hex(value)

          :integer when is_binary(value) ->
            value
            |> load_hex()
            |> :binary.decode_unsigned()

          :raw ->
            value
        end
    end
  end
end
