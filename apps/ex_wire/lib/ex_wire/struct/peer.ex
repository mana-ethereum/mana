defmodule ExWire.Struct.Peer do
  @moduledoc """
  Represents a Peer for an RLPx / Eth Wire connection.
  """

  defstruct [
    :host,
    :port,
    :remote_id,
    :ident
  ]

  alias ExthCrypto.Key
  alias ExWire.Crypto
  alias ExWire.Kademlia.Node

  @type t :: %__MODULE__{
          host: :inet.socket_address() | :inet.hostname(),
          port: :inet.port_number(),
          remote_id: Key.public_key(),
          ident: String.t()
        }

  @doc """
  Constructs a new Peer struct.

  ## Examples

      iex> ExWire.Struct.Peer.new({13, 84, 180, 240}, 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d")
      %ExWire.Struct.Peer{
        host: {13, 84, 180, 240},
        port: 30303,
        remote_id: <<108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }
  """
  @spec new(:inet.socket_address() | :inet.hostname(), integer(), String.t()) :: t()
  def new(host, port, remote_id_hex) do
    remote_id =
      remote_id_hex
      |> Crypto.hex_to_bin()

    ident = Binary.take(remote_id_hex, 6) <> "..." <> Binary.take(remote_id_hex, -6)

    %__MODULE__{
      host: host,
      port: port,
      remote_id: remote_id,
      ident: ident
    }
  end

  @doc """
  Returns the hex node id format of a Peer's remote_id public key.

  ## Examples

      iex> remote_id = <<108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>
      iex> ExWire.Struct.Peer.hex_node_id(remote_id)
      "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d"
  """
  @spec hex_node_id(Key.public_key()) :: String.t()
  def hex_node_id(remote_id) do
    remote_id
    |> Crypto.bin_to_hex()
  end

  @doc """
  Constructs a peer from a URI.

  ## Examples

      iex> ExWire.Struct.Peer.from_uri("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@13.84.180.240:30303")
      {:ok, %ExWire.Struct.Peer{
        host: {13, 84, 180, 240},
        port: 30303,
        remote_id: <<108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }}

      iex> ExWire.Struct.Peer.from_uri("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@[::]:30303")
      {:ok, %ExWire.Struct.Peer{
        host: {0, 0, 0, 0, 0, 0, 0, 0},
        port: 30303,
        remote_id: <<108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }}

      iex> ExWire.Struct.Peer.from_uri("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@google.com:30303")
      {:ok, %ExWire.Struct.Peer{
        host: 'google.com',
        port: 30303,
        remote_id: <<108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }}

      iex> ExWire.Struct.Peer.from_uri("http://id@google.com:30303")
      {:error, "URI scheme must be enode, got http"}

      iex> ExWire.Struct.Peer.from_uri("abc")
      {:error, "Invalid URI"}
  """
  @spec from_uri(String.t()) :: {:ok, t} | {:error, String.t()}
  def from_uri(uri) do
    case URI.parse(uri) do
      %URI{scheme: nil} ->
        {:error, "Invalid URI"}

      %URI{host: nil} ->
        {:error, "Missing hostname"}

      %URI{
        scheme: "enode",
        userinfo: remote_id_hex,
        host: host,
        port: port
      } ->
        {:ok, __MODULE__.new(uri_host_to_inet_host(host), port, remote_id_hex)}

      %URI{scheme: scheme} ->
        {:error, "URI scheme must be enode, got #{scheme}"}
    end
  end

  # Tries to parse a host as an IP address, as this is required
  # by `gen_tcp` since addresses such as "::1" get correctly
  # parsed as an IPv6 address. If it fails to parse as an ip address
  # we just return the hostname as a charlist.
  @spec uri_host_to_inet_host(String.t()) :: :inet.socket_address() | :inet.hostname()
  defp uri_host_to_inet_host(host) do
    hostname_chars = String.to_charlist(host)

    case :inet.parse_address(hostname_chars) do
      {:ok, ip_address} ->
        ip_address

      {:error, _} ->
        hostname_chars
    end
  end

  @doc """
  Creates a node struct from a Kademlia node.

  ## Examples

      iex> %ExWire.Kademlia.Node{
      ...>  endpoint: %ExWire.Struct.Endpoint{
      ...>    ip: [52, 169, 14, 227],
      ...>    tcp_port: nil,
      ...>    udp_port: 30303
      ...>  },
      ...>  key: <<202, 107, 222, 100, 235, 37, 246, 148, 81, 241, 131, 186, 231, 136, 53,
      ...>    244, 150, 181, 223, 94, 85, 8, 248, 17, 242, 130, 233, 242, 131, 19, 153,
      ...>    173>>,
      ...>  public_key: <<32, 201, 173, 151, 192, 129, 214, 51, 151, 215, 182, 133, 164,
      ...>    18, 34, 122, 64, 226, 60, 139, 220, 102, 136, 198, 243, 126, 151, 207, 188,
      ...>    34, 210, 180, 209, 219, 21, 16, 216, 246, 30, 106, 136, 102, 173, 127, 14,
      ...>    23, 192, 43, 20, 24, 45, 55, 234, 124, 60, 139, 156, 38, 131, 174, 182, 183,
      ...>    51, 161>>
      ...> } |> ExWire.Struct.Peer.from_node()
      %ExWire.Struct.Peer{
        host: {52, 169, 14, 227},
        ident: "20c9ad...b733a1",
        port: nil,
        remote_id: <<32, 201, 173, 151, 192, 129, 214, 51, 151, 215, 182, 133, 164,
          18, 34, 122, 64, 226, 60, 139, 220, 102, 136, 198, 243, 126, 151, 207, 188,
          34, 210, 180, 209, 219, 21, 16, 216, 246, 30, 106, 136, 102, 173, 127, 14,
          23, 192, 43, 20, 24, 45, 55, 234, 124, 60, 139, 156, 38, 131, 174, 182, 183,
          51, 161>>
      }
  """
  @spec from_node(Node.t()) :: t()
  def from_node(kademlia_node) do
    __MODULE__.new(
      Enum.join(List.to_tuple(kademlia_node.endpoint.ip), "."),
      kademlia_node.endpoint.tcp_port,
      Crypto.bin_to_hex(kademlia_node.public_key)
    )
  end
end

defimpl String.Chars, for: ExWire.Struct.Peer do
  @spec to_string(ExWire.Struct.Peer.t()) :: String.t()
  def to_string(peer) do
    peer.ident
  end
end
