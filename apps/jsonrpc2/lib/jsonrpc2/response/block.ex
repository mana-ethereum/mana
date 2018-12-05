defmodule JSONRPC2.Response.Block do
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

  def new(internal_block) do
    %__MODULE__{
      number: internal_block.header.number,
      hash: encode_hex(internal_block.block_hash),
      parentHash: encode_hex(internal_block.header.parent_hash),
      nonce: encode_hex(internal_block.header.nonce),
      sha3Uncles: nil,
      logsBloom: encode_hex(internal_block.header.logs_bloom),
      transactionsRoot: encode_hex(internal_block.header.transactions_root),
      stateRoot: encode_hex(internal_block.header.state_root),
      receiptsRoot: encode_hex(internal_block.header.receipts_root),
      miner: encode_hex(internal_block.header.beneficiary),
      difficulty: internal_block.header.difficulty,
      totalDifficulty: nil,
      extraData: internal_block.header.extra_data,
      size: nil,
      gasLimit: internal_block.header.gas_limit,
      gasUsed: internal_block.header.gas_used,
      timestamp: internal_block.header.timestamp,
      transactions: [],
      uncles: []
    }
  end
end
