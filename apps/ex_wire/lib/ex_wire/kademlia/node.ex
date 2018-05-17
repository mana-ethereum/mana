defmodule ExWire.Kademlia.Node do
  @moduledoc """
  Represents a node in Kademlia algorithm; an entity on the network.
  """
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Kademlia.XorDistance
  alias ExWire.Struct.Endpoint

  defstruct [
    :public_key,
    :key,
    :endpoint
  ]

  @type t :: %__MODULE__{
          public_key: binary(),
          key: binary(),
          endpoint: Endpoint.t()
        }

  @doc """
  Constructs a new node.

  ## Examples

      iex> endpoint = ExWire.Struct.Endpoint.decode([<<1,2,3,4>>, <<>>, <<5>>])
      iex> ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>      124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>      148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>      86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
      ...>      endpoint)
      %ExWire.Kademlia.Node{
        endpoint: %ExWire.Struct.Endpoint{
          ip: [1, 2, 3, 4],
          tcp_port: 5,
          udp_port: nil
        },
        key: <<115, 3, 97, 5, 230, 214, 202, 188, 202, 118, 204, 177, 15, 72, 13, 68,
          134, 100, 145, 57, 13, 239, 13, 175, 42, 38, 147, 127, 31, 18, 27, 226>>,
        public_key: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
          124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
          148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
          86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
          157>>
      }
  """
  @spec new(binary(), Endpoint) :: t()
  def new(public_key, endpoint = %Endpoint{}) do
    key = Keccak.kec(public_key)

    %__MODULE__{
      public_key: public_key,
      key: key,
      endpoint: endpoint
    }
  end

  @doc """
  Calculates distance between two nodes.

  ## Examples

      iex> node1 = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>       124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>       148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>       86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>       157>>, ExWire.Struct.Endpoint.decode([<<1,2,3,4>>, <<>>, <<5>>]))
      iex> node2 = ExWire.Kademlia.Node.new(<<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
      ...>       62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
      ...>       46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
      ...>       23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
      ...>       214, 6>>, ExWire.Struct.Endpoint.decode([<<5, 6, 7, 8>>, <<>>, <<5>>]))
      iex> ExWire.Kademlia.Node.distance(node1, node2)
      131
  """
  @spec distance(t(), t()) :: integer()
  def distance(%__MODULE__{key: key1}, %__MODULE__{key: key2}) do
    XorDistance.distance(key1, key2)
  end

  @doc """
  Calculates common id prefix between two peers.

  ## Examples

      iex> node1 = ExWire.Kademlia.Node.new(<<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79,
      ...>         124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48,
      ...>         148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42,
      ...>         86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205,
      ...>         157>>, ExWire.Struct.Endpoint.decode([<<1,2,3,4>>, <<>>, <<5>>]))
      iex> node2 = ExWire.Kademlia.Node.new(<<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
      ...>         62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
      ...>         46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
      ...>         23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
      ...>         214, 6>>, ExWire.Struct.Endpoint.decode([<<5, 6, 7, 8>>, <<>>, <<5>>]))
      iex> ExWire.Kademlia.Node.common_prefix(node1, node2)
      0
  """
  @spec common_prefix(t(), t()) :: integer()
  def common_prefix(%__MODULE__{key: key1}, %__MODULE__{key: key2}) do
    XorDistance.common_prefix(key1, key2)
  end
end
