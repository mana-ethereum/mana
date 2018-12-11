defmodule JSONRPC2.Response.Block do
  alias Blockchain.Block
  alias Blockchain.Transaction
  alias ExthCrypto.Hash.Keccak
  alias JSONRPC2.Response.Transaction, as: ResponseTransaction

  import JSONRPC2.Response.Helpers

  @derive Jason.Encoder
  defstruct [
    :number,
    :hash,
    :parentHash,
    :nonce,
    :sha3Uncles,
    :logsBloom,
    :transactionsRoot,
    :stateRoot,
    :receiptsRoot,
    :miner,
    :difficulty,
    :totalDifficulty,
    :extraData,
    :size,
    :gasLimit,
    :gasUsed,
    :timestamp,
    :transactions,
    :uncles
  ]

  @type transactions :: [binary()] | [ResponseTransaction.t()]

  @type t :: %__MODULE__{
          number: binary(),
          hash: binary(),
          parentHash: binary(),
          nonce: binary(),
          sha3Uncles: binary(),
          logsBloom: binary(),
          transactionsRoot: binary(),
          stateRoot: binary(),
          receiptsRoot: binary(),
          miner: binary(),
          difficulty: binary(),
          totalDifficulty: binary(),
          extraData: binary(),
          size: binary(),
          gasLimit: binary(),
          gasUsed: binary(),
          timestamp: binary(),
          transactions: transactions(),
          uncles: []
        }

  @spec new(Block.t(), boolean()) :: t()
  def new(internal_block, include_full_transactions \\ false) do
    %__MODULE__{
      number: encode_hex(internal_block.header.number),
      hash: encode_hex(internal_block.block_hash),
      parentHash: encode_hex(internal_block.header.parent_hash),
      nonce: encode_hex(internal_block.header.nonce),
      sha3Uncles: encode_hex(internal_block.header.ommers_hash),
      logsBloom: encode_hex(internal_block.header.logs_bloom),
      transactionsRoot: encode_hex(internal_block.header.transactions_root),
      stateRoot: encode_hex(internal_block.header.state_root),
      receiptsRoot: encode_hex(internal_block.header.receipts_root),
      miner: encode_hex(internal_block.header.beneficiary),
      difficulty: encode_hex(internal_block.header.difficulty),
      totalDifficulty: encode_hex(internal_block.header.total_difficulty || 0),
      extraData: internal_block.header.extra_data,
      size: encode_hex(internal_block.header.size || block_size(internal_block)),
      gasLimit: encode_hex(internal_block.header.gas_limit),
      gasUsed: encode_hex(internal_block.header.gas_used),
      timestamp: encode_hex(internal_block.header.timestamp),
      transactions:
        format_transactions(
          internal_block.transactions,
          internal_block,
          include_full_transactions
        ),
      uncles: []
    }
  end

  @spec block_size(Block.t()) :: integer()
  defp block_size(block) do
    block
    |> Block.serialize()
    |> ExRLP.encode()
    |> byte_size()
  end

  @spec format_transactions([Transaction.t()], Block.t(), boolean()) ::
          [ResponseTransaction.t()] | [binary()]
  def transactions(transactions, block, true) do
    Enum.map(transactions, fn transaction ->
      ResponseTransaction.new(transaction, block)
    end)
  end

  def format_transactions(transactions, _, _) do
    Enum.map(transactions, fn transaction ->
      transaction
      |> Transaction.serialize()
      |> ExRLP.encode()
      |> Keccak.kec()
      |> encode_hex()
    end)
  end
end
