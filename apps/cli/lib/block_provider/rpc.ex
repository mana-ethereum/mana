defmodule CLI.BlockProvider.RPC do
  @moduledoc """
  Provider which can pulls from another full node via RPC.
  This can be via HTTP(s) or IPC.
  """
  require Logger

  alias Block.Header
  alias Blockchain.{Block, Blocktree, Chain, Transaction}
  alias Ethereumex.{HttpClient, IpcClient}
  alias MerklePatriciaTree.DB

  @max_retries 5

  @type ethereumex_client :: module()
  @type state :: ethereumex_client()

  @doc """
  Sets up database and loads chain information.
  """
  @spec setup(String.t() | nil) :: {:ok, state()} | {:error, any()}
  def setup(provider_url) do
    state =
      case URI.parse(provider_url) do
        %URI{scheme: scheme} when scheme == "http" or scheme == "https" ->
          :ok = Application.put_env(:ethereumex, :url, provider_url)
          :ok = Application.put_env(:ethereumex, :client_type, :http)

          {:ok, HttpClient}

        %URI{scheme: "ipc", path: ipc_path} ->
          :ok = Application.put_env(:ethereumex, :ipc_path, ipc_path)
          :ok = Application.put_env(:ethereumex, :client_type, :ipc)

          {:ok, IpcClient}

        els ->
          {:error, "Unknown scheme for #{inspect(els)}"}
      end

    {:ok, _started} = Application.ensure_all_started(:ethereumex)

    state
  end

  @doc """
  Returns the highest known block number. This is used for progress tracking.
  """
  @spec get_block_number(ethereumex_client(), integer()) :: {:ok, integer()} | {:error, any()}
  def get_block_number(client, retries \\ @max_retries) do
    case client.eth_block_number() do
      {:ok, block_number} ->
        {:ok, decode_integer(block_number)}

      {:error, error} ->
        if retries > 0 do
          Logger.info("Error loading block number, retrying: #{inspect(error)}")
          get_block_number(client, retries - 1)
        else
          {:error, error}
        end
    end
  end

  @doc """
  Retrieves a block from the full node via an RPC call.
  """
  @spec get_block(integer(), state()) :: {:ok, Block.t(), state()} | {:error, any()}
  def get_block(number, client) do
    with {:ok, block_data} <- load_new_block(number, client) do
      block = %Block{
        block_hash: get(block_data, "hash"),
        header: %Header{
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

            %Transaction{
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
              get(block_data, "hash", :raw),
              to_hex(index)
            )

          %Header{
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

      block_with_ommers = Block.add_ommers(block, ommers)

      {:ok, block_with_ommers, client}
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
            decode_integer(value)

          :raw ->
            value
        end
    end
  end

  @spec decode_integer(String.t()) :: integer()
  defp decode_integer(value) do
    value
    |> load_hex()
    |> :binary.decode_unsigned()
  end
end
