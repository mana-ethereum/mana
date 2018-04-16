defmodule ExRLP do
  alias ExRLP.{Encoder, Decoder}

  @moduledoc File.read!("#{__DIR__}/../README.md")

  @type t :: nil | binary() | integer() | [t]

  @doc """
  Given an RLP structure, returns the encoding as a string.

  ## Examples

    iex> ExRLP.encode("dog")
    <<0x83, ?d, ?o, ?g>>

    iex> ExRLP.encode("dog", encoding: :hex)
    "83646f67"

    iex> ExRLP.encode(Enum.join(for _ <- 1..60, do: "A"))
    <<184, 60, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65>>

    iex> ExRLP.encode(["cat", "dog"])
    <<0xc8, 0x83, ?c, ?a, ?t, 0x83, ?d, ?o, ?g>>

    iex> ExRLP.encode("")
    <<0x80>>

    iex> ExRLP.encode([])
    <<0xc0>>

    iex> ExRLP.encode("\x0f")
    <<0x0f>>

    iex> ExRLP.encode(15)
    <<0x0f>>

    iex> ExRLP.encode(15_000_000_000_000_000_000_000_000_000_000_000)
    <<143, 2, 227, 142, 158, 4, 75, 160, 83, 84, 85, 150, 0, 0, 0, 0>>

    iex> ExRLP.encode(1024)
    <<0x82, 0x04, 0x00>>

    iex> ExRLP.encode("\x04\x00")
    <<0x82, 0x04, 0x00>>

    iex> ExRLP.encode([[],[[]],[[],[[]]]])
    <<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>

    iex> ExRLP.encode(for _ <- 1..60, do: [])
    <<248, 60, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192>>
  """
  @spec encode(t) :: binary()
  @spec encode(t, keyword()) :: binary()
  def encode(item, options \\ []) do
    item |> Encoder.encode(options)
  end

  @doc """
  Given an RLP-encoded string, returns a decoded RPL structure (which is an array of RLP structures or binaries).

  ## Examples

    iex> ExRLP.decode(<<>>)
    nil

    iex> ExRLP.decode(<<0x83, ?d, ?o, ?g>>)
    "dog"

    iex> ExRLP.decode("83646f67", :binary, encoding: :hex)
    "dog"

    iex> ExRLP.decode(<<184, 60, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65>>)
    Enum.join(for _ <- 1..60, do: "A")

    iex> ExRLP.decode(<<0xc8, 0x83, ?c, ?a, ?t, 0x83, ?d, ?o, ?g>>)
    ["cat", "dog"]

    iex> ExRLP.decode(<<198, 51, 132, 99, 111, 111, 108>>)
    ["3", "cool"]

    iex> ExRLP.decode(<<0x80>>)
    ""

    iex> ExRLP.decode(<<0xc0>>)
    []

    iex> ExRLP.decode(<<0x0f>>)
    <<0x0f>>

    iex> ExRLP.decode(<<0x82, 0x04, 0x00>>)
    "\x04\x00"

    iex> ExRLP.decode(<<0xc7, 0xc0, 0xc1, 0xc0, 0xc3, 0xc0, 0xc1, 0xc0>>)
    [[],[[]],[[],[[]]]]

    iex> ExRLP.decode(<<248, 60, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192, 192>>)
    for _ <- 1..60, do: []

    iex> ExRLP.decode(<<143, 2, 227, 142, 158, 4, 75, 160, 83, 84, 85, 150, 0, 0, 0, 0>>) |> :binary.decode_unsigned
    15_000_000_000_000_000_000_000_000_000_000_000
  """
  @spec decode(binary()) :: t
  @spec decode(binary(), atom()) :: t
  @spec decode(binary(), atom(), keyword()) :: t
  def decode(item, type \\ :binary, options \\ []) do
    item |> Decoder.decode(type, options)
  end
end
