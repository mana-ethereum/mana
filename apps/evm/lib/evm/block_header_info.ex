defmodule EVM.BlockHeaderInfo do
  @moduledoc """
  Module for interacting with the a block header.
  """

  @type t :: struct()
  @type nth_ancestor :: non_neg_integer()

  @callback get_block_header(t) :: Block.Header.t()
  @callback get_ancestor_header(t, nth_ancestor()) :: Block.Header.t() | nil

  @doc """
  Gets a block header for an implementation.
  """
  @spec block_header(t) :: Block.Header.t()
  def block_header(block_header_info) do
    impl_module(block_header_info).get_block_header(block_header_info)
  end

  @doc """
  Gets the nth ancestor's block header.
  """
  @spec ancestor_header(t, nth_ancestor()) :: Block.Header.t() | nil
  def ancestor_header(block_header_info, nth_ancestor) do
    impl_module(block_header_info).get_ancestor_header(block_header_info, nth_ancestor)
  end

  @spec impl_module(t) :: module()
  defp impl_module(block_header_info) do
    block_header_info.__struct__
  end
end
