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

      iex> EVM.LogEntry.new(0, [0, 0, 0, 0], <<1>>)
      %EVM.LogEntry{
        address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        data: <<1>>,
        topics: [
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        ]
      }

      iex> EVM.LogEntry.new( <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109, 45, 108, 123, 94, 198>>, [0, 0, 0, 0], <<1>>)
      %EVM.LogEntry{
        address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47, 109,
          45, 108, 123, 94, 198>>,
        data: <<1>>,
        topics: [
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        ]
      }
  """
  @spec new(integer() | binary(), [integer()], binary()) :: t()
  def new(address, topics, data) do
    address =
      if is_number(address),
        do: Address.new(address),
        else: address

    normalized_topics = normalize_topics(topics)

    %__MODULE__{
      address: address,
      topics: normalized_topics,
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
        [0, 0, 0],
        <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
          255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
          255, 255>>
      ]

  """
  @spec to_list(t()) :: [binary()]
  def to_list(log) do
    [log.address, log.topics, log.data]
  end

  defp normalize_topics(topics, acc \\ [])

  defp normalize_topics([], acc), do: acc

  defp normalize_topics([topic | tail], acc) when is_integer(topic) do
    bin_topic = :binary.encode_unsigned(topic)

    normalize_topics([bin_topic | tail], acc)
  end

  defp normalize_topics([topic | tail], acc) do
    padded_topic = Helpers.left_pad_bytes(topic)

    normalize_topics(tail, acc ++ [padded_topic])
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
