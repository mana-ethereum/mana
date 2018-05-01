defmodule EVM.LogEntry do
  @moduledoc """
  This module contains functions to work with logs.
  """

  alias EVM.{Address, Helpers}

  defstruct address: nil, topics: [], data: nil

  @type t :: %__MODULE__{
          address: EVM.address(),
          topics: [binary()],
          data: binary()
        }

  @doc """
  Creates new log entry.

  ## Examples

      iex> log = EVM.LogEntry.new(0, [0, 0, 0, 0], <<1>>)
      %EVM.LogEntry{
        address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        data: <<1>>,
        topics: [0, 0, 0, 0]
      }

      iex> log = EVM.LogEntry.new( <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109, 45, 108, 123, 94, 198>>, [0, 0, 0, 0], <<1>>)
      %EVM.LogEntry{
        address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109,
          45, 108, 123, 94, 198>>,
        data: <<1>>,
        topics: [0, 0, 0, 0]
      }
  """
  @spec new(integer() | binary(), [integer()], binary()) :: t()
  def new(address, topics, data) do
    address = if is_number(address), do: address |> Address.new(), else: address

    %__MODULE__{
      address: address,
      topics: topics,
      data: data
    }
  end

  @doc """
  Converts log struct to standard Ethereum list representation.

  ## Examples

      iex> log = %EVM.LogEntry{
      ...> address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109,
      ...>       45, 108, 123, 94, 198>>,
      ...> data: <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>       255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>       255, 255, 255>>,
      ...> topics: [0, 0, 0]
      ...> }
      iex> log |> EVM.LogEntry.to_list
      [
        <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109, 45, 108,
          123, 94, 198>>,
        [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0>>
        ],
        <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
          255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
          255, 255>>
      ]

  """
  @spec to_list(t()) :: [binary()]
  def to_list(log) do
    topics =
      log.topics
      |> Enum.map(fn topic ->
        topic |> Helpers.left_pad_bytes()
      end)

    [log.address, topics, log.data]
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
