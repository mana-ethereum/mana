defmodule ExWire.Kademlia.Node do
  @moduledoc """
  Represents a node in Kademlia algorithm; an entity on the network.
  """
  alias ExWire.{Crypto, Message}
  alias ExWire.Handler.Params
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

      iex> address = "enode://20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1@52.169.14.227:30303"
      iex> ExWire.Kademlia.Node.new(address)
      %ExWire.Kademlia.Node{
        endpoint: %ExWire.Struct.Endpoint{
          ip: [52, 169, 14, 227],
          tcp_port: nil,
          udp_port: 30303
        },
        key: <<202, 107, 222, 100, 235, 37, 246, 148, 81, 241, 131, 186, 231, 136, 53,
          244, 150, 181, 223, 94, 85, 8, 248, 17, 242, 130, 233, 242, 131, 19, 153,
          173>>,
        public_key: <<32, 201, 173, 151, 192, 129, 214, 51, 151, 215, 182, 133, 164,
          18, 34, 122, 64, 226, 60, 139, 220, 102, 136, 198, 243, 126, 151, 207, 188,
          34, 210, 180, 209, 219, 21, 16, 216, 246, 30, 106, 136, 102, 173, 127, 14,
          23, 192, 43, 20, 24, 45, 55, 234, 124, 60, 139, 156, 38, 131, 174, 182, 183,
          51, 161>>
       }

  """
  @spec new(binary(), Endpoint) :: t()
  def new(public_key, endpoint = %Endpoint{}) do
    key = Crypto.hash(public_key)

    %__MODULE__{
      public_key: public_key,
      key: key,
      endpoint: endpoint
    }
  end

  @spec new(binary()) :: t()
  def new(enode_address) when is_binary(enode_address) do
    %URI{
      scheme: _scheme,
      userinfo: remote_id,
      host: remote_host,
      port: remote_peer_port
    } = URI.parse(enode_address)

    remote_ip =
      with {:ok, remote_ip} <- :inet.ip(remote_host |> String.to_charlist()) do
        remote_ip |> Tuple.to_list()
      end

    endpoint = %Endpoint{
      ip: remote_ip,
      udp_port: remote_peer_port
    }

    public_key = Crypto.hex_to_bin(remote_id)

    new(public_key, endpoint)
  end

  @doc """
  Creates a new Node struct form ExWire.Handler.Params

  ## Examples

      iex> params = %ExWire.Handler.Params{
      ...>   remote_host: %ExWire.Struct.Endpoint{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63,
      ...>     232, 67, 152, 216, 249, 89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152,
      ...>     134, 149, 220, 73, 198, 29, 93, 218, 123, 50, 70, 8, 202, 17, 171, 67, 245,
      ...>     70, 235, 163, 158, 201, 246, 223, 114, 168, 7, 7, 95, 9, 53, 165, 8, 177,
      ...>     13>>,
      ...>   recovery_id: 1,
      ...>   hash: <<5>>,
      ...>   data: [1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
      ...>   timestamp: 123,
      ...>   type: 2
      ...> }
      iex> ExWire.Kademlia.Node.from_handler_params(params)
      %ExWire.Kademlia.Node{
        endpoint: %ExWire.Struct.Endpoint{
          ip: [1, 2, 3, 4],
          tcp_port: nil,
          udp_port: 55
        },
        key: <<82, 25, 231, 209, 101, 209, 232, 115, 33, 237, 181, 81, 181, 2, 202,
          77, 181, 78, 159, 231, 221, 144, 198, 11, 123, 132, 136, 183, 135, 31, 207,
          141>>,
        public_key: <<153, 149, 149, 167, 201, 115, 154, 11, 141, 233, 49, 71, 229,
          202, 25, 84, 59, 111, 153, 217, 57, 132, 148, 55, 195, 58, 42, 211, 227,
          178, 122, 26, 23, 85, 51, 240, 231, 4, 255, 112, 141, 5, 6, 222, 217, 181,
          49, 46, 46, 23, 149, 27, 253, 38, 20, 167, 95, 161, 175, 72, 195, 134, 234,
          158>>
      }
  """
  @spec from_handler_params(Params.t()) :: t()
  def from_handler_params(params) do
    public_key =
      (<<params.type>> <> params.data)
      |> Message.recover_public_key(params.signature, params.recovery_id)
      |> Crypto.node_id_from_public_key()

    new(public_key, params.remote_host)
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
