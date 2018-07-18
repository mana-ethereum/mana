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

  alias ExWire.Crypto

  @type t :: %__MODULE__{
          host: String.t(),
          port: integer(),
          remote_id: String.t(),
          ident: String.t()
        }

  @doc """
  Constructs a new Peer struct.

  ## Examples

      iex> ExWire.Struct.Peer.new("13.84.180.240", 30303, "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d")
      %ExWire.Struct.Peer{
        host: "13.84.180.240",
        port: 30303,
        remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }
  """
  @spec new(String.t(), integer(), String.t()) :: t
  def new(host, port, remote_id_hex) do
    remote_id =
      remote_id_hex
      |> Crypto.hex_to_bin()
      |> Crypto.raw_to_der()

    ident = Binary.take(remote_id_hex, 6) <> "..." <> Binary.take(remote_id_hex, -6)

    %__MODULE__{
      host: host,
      port: port,
      remote_id: remote_id,
      ident: ident
    }
  end

  @doc """
  Returns the hex node id format of a Peer's remote_id.

  ## Examples

      iex> remote_id = <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>
      iex> ExWire.Struct.Peer.hex_node_id(remote_id)
      "6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d"
  """
  @spec hex_node_id(String.t()) :: String.t()
  def hex_node_id(remote_id) do
    remote_id
    |> Crypto.der_to_raw()
    |> Crypto.bin_to_hex()
  end

  @doc """
  Constructs a peer from a URI.

  ## Examples

      iex> ExWire.Struct.Peer.from_uri("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@13.84.180.240:30303")
      {:ok, %ExWire.Struct.Peer{
        host: "13.84.180.240",
        port: 30303,
        remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
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
      %URI{
        scheme: "enode",
        userinfo: remote_id_hex,
        host: host,
        port: port
      } ->
        {:ok, __MODULE__.new(host, port, remote_id_hex)}

      %URI{scheme: nil} ->
        {:error, "Invalid URI"}

      %URI{scheme: scheme} ->
        {:error, "URI scheme must be enode, got #{scheme}"}
    end
  end
end

defimpl String.Chars, for: ExWire.Struct.Peer do
  @spec to_string(ExWire.Struct.Peer.t()) :: String.t()
  def to_string(peer) do
    peer.ident
  end
end
