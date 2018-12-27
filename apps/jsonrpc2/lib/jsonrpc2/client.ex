defmodule JSONRPC2.Client do
  alias JSONRPC2.Response.Block, as: ResponseBlock
  alias JSONRPC2.Response.Receipt, as: ResponseReceipt
  alias JSONRPC2.Response.Transaction, as: ResponseTransaction

  @type implementation :: struct()

  @callback connected_peer_count() :: 0 | non_neg_integer()
  @callback last_sync_block_stats() ::
              {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  @callback block(binary() | non_neg_integer(), boolean()) :: ResponseBlock.t() | nil
  @callback transaction_by_block_and_index(non_neg_integer(), non_neg_integer()) ::
              ResponseTransaction.t() | nil
  @callback transaction_by_hash(binary()) :: ResponseTransaction.t() | nil
  @callback block_transaction_count(non_neg_integer() | binary()) :: binary() | nil
  @callback uncle_count(non_neg_integer() | binary()) :: binary() | nil
  @callback starting_block_number() :: non_neg_integer()
  @callback highest_block_number() :: non_neg_integer()
  @callback code(binary(), non_neg_integer()) :: binary() | nil
  @callback balance(binary(), non_neg_integer()) :: binary() | nil
  @callback transaction_receipt(binary()) :: ResponseReceipt.t() | nil
  @callback uncle(binary() | non_neg_integer(), non_neg_integer()) :: ResponseBlock.t() | nil
  @callback storage(binary(), non_neg_integer(), non_neg_integer) :: binary() | nil
  @callback transaction_count(binary(), non_neg_integer()) :: binary() | nil
end
