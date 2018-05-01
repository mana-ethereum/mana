defmodule EVM.LogEntry do
  @moduledoc """
  This module contains functions to work with logs.
  """

  alias EVM.Address

  defstruct address: nil, topics: [], data: nil

  @type t :: %__MODULE__{
          address: EVM.address(),
          topics: [binary()],
          data: binary()
        }

  @spec new(integer() | binary(), [integer()], binary()) :: t()
  def new(address, topics, data) do
    address = if is_number(address), do: address |> Address.new(), else: address

    %__MODULE__{
      address: address,
      topics: topics,
      data: data
    }
  end

  @spec to_list(t()) :: [binary()]
  def to_list(log) do
    [log.address, log.topics, log.data]
  end
end

defimpl ExRLP.Encode, for: EVM.LogEntry do
  alias ExRLP.Encode
  alias EVM.LogEntry

  @spec encode(LogEntry.t(), keyword()) :: binary()
  def encode(log, options \\ []) do
    log
    |> LogEntry.to_list()
    |> Encode.encode(options)
  end
end
