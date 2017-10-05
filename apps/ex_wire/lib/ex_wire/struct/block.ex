defmodule ExWire.Struct.Block do
  @moduledoc """
  A struct for storing blocks as they are transported over the Eth Wire Protocol.
  """

  defstruct [
    :transaction_list,
    :uncle_list
  ]

  @type t :: %__MODULE__{
    transaction_list: [any()],
    uncle_list: [any()]
  }

  @doc """
  Given a Block, serializes for transport over Eth Wire Protocol.

  ## Examples

      iex> %ExWire.Struct.Block{transaction_list: [], uncle_list: []}
      ...> |> ExWire.Struct.Block.serialize
      [[], []]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(struct) do
    [
      struct.transaction_list,
      struct.uncle_list
    ]
  end

  @doc """
  Given an RLP-encoded block from Eth Wire Protocol,
  decodes into a Block struct.

  ## Examples

      iex> ExWire.Struct.Block.deserialize([[], []])
      %ExWire.Struct.Block{transaction_list: [], uncle_list: []}
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      transaction_list,
      uncle_list
    ] = rlp

    %__MODULE__{
      transaction_list: transaction_list,
      uncle_list: uncle_list
    }
  end

end