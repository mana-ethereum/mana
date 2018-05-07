defmodule ExWire.Struct.Bucket do
  @moduledoc """
  Represents a Kademlia k-bucket.
  """

  alias ExWire.Struct.{Peer, Bucket}
  alias ExWire.Util.Timestamp

  defstruct [:current_node, :nodes, :updated_at]

  @type t :: %__MODULE__{
    current_node: Peer.t(),
    nodes: [Peer.t()],
    updated_at: integer()
  }

  @doc """
  Creates new bucket.

  ## Examples

      iex> node = ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d", time: :test)
      iex> node |> ExWire.Struct.Bucket.new(time: :test)
      %ExWire.Struct.Bucket{
        current_node: %ExWire.Struct.Peer{
          host: "13.84.180.240",
          ident: "6ce059...1acd9d",
          last_seen: 1525704921,
          port: 30303,
          remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50,
            79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72,
            48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85,
            42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186,
            26, 205, 157>>
        },
        nodes: [],
        updated_at: 1525704921
      }

  """
  @spec new(Peer.t()) :: t()
  def new(node = %Peer{}, options \\ [time: :actual]) do
    %__MODULE__{
      current_node: node,
      nodes: [],
      updated_at: Timestamp.now(options[:time])
    }
  end
end
