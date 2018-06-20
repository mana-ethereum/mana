defprotocol EVM.Interface.BlockInterface do
  @moduledoc """
  Interface for interacting with block headers.
  """

  alias EthCore.Block.Header

  @type t :: module()

  @spec get_block_header(t) :: Header.t()
  def get_block_header(t)

  @spec get_block_by_hash(t, EVM.hash()) :: Header.t() | nil
  def get_block_by_hash(t, block_hash)

  @spec get_block_by_number(t, non_neg_integer()) :: Header.t() | nil
  def get_block_by_number(t, steps)
end
