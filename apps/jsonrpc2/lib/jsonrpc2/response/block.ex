defmodule JSONRPC2.Response.Block do
  alias Block.Header
  alias Blockchain.Block
  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature
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
          uncles: [binary()]
        }

  @spec new(Block.t(), boolean()) :: t()
  def new(internal_block, include_full_transactions \\ false) do
    %__MODULE__{
      number: encode_quantity(internal_block.header.number),
      hash: encode_unformatted_data(internal_block.block_hash),
      parentHash: encode_unformatted_data(internal_block.header.parent_hash),
      nonce: encode_unformatted_data(internal_block.header.nonce),
      sha3Uncles: encode_unformatted_data(internal_block.header.ommers_hash),
      logsBloom: encode_unformatted_data(internal_block.header.logs_bloom),
      transactionsRoot: encode_unformatted_data(internal_block.header.transactions_root),
      stateRoot: encode_unformatted_data(internal_block.header.state_root),
      receiptsRoot: encode_unformatted_data(internal_block.header.receipts_root),
      miner: encode_unformatted_data(internal_block.header.beneficiary),
      difficulty: encode_quantity(internal_block.header.difficulty),
      totalDifficulty: encode_quantity(internal_block.header.total_difficulty || 0),
      extraData: encode_unformatted_data(internal_block.header.extra_data),
      size: encode_quantity(internal_block.header.size || block_size(internal_block)),
      gasLimit: encode_quantity(internal_block.header.gas_limit),
      gasUsed: encode_quantity(internal_block.header.gas_used),
      timestamp: encode_quantity(internal_block.header.timestamp),
      transactions:
        format_transactions(
          internal_block.transactions,
          internal_block,
          include_full_transactions
        ),
      uncles: format_uncles(internal_block.ommers)
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
  def format_transactions(transactions, block, true) do
    Enum.map(transactions, fn transaction ->
      ResponseTransaction.new(transaction, block)
    end)
  end

  def format_transactions(transactions, _, _) do
    Enum.map(transactions, fn transaction ->
      transaction
      |> Signature.transaction_hash()
      |> encode_unformatted_data()
    end)
  end

  @spec format_uncles([Header.t()]) :: [binary()]
  def format_uncles(uncles) do
    Enum.map(uncles, fn uncle ->
      uncle
      |> Header.hash()
      |> encode_unformatted_data()
    end)
  end
end
