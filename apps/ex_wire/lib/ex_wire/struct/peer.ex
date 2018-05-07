defmodule ExWire.Struct.Peer do
  @moduledoc """
  Represents a Peer for an RLPx / Eth Wire connection.
  """
  alias ExWire.Struct.Peer
  use Bitwise

  defstruct [
    :host,
    :port,
    :remote_id,
    :ident
  ]

  @type t :: %__MODULE__{
    host: String.t,
    port: integer(),
    remote_id: String.t,
    ident: String.t,
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
  @spec new(Sring.t, integer(), String.t) :: t
  def new(host, port, remote_id_hex) do
    remote_id = remote_id_hex |> ExthCrypto.Math.hex_to_bin |> ExthCrypto.Key.raw_to_der
    ident = Binary.take(remote_id_hex, 6) <> "..." <> Binary.take(remote_id_hex, -6)

    %__MODULE__{
      host: host,
      port: port,
      remote_id: remote_id,
      ident: ident
    }
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
  @spec from_uri(String.t) :: {:ok, t} | {:error, String.t}
  def from_uri(uri) do
    case URI.parse(uri) do
      %URI{
        scheme: "enode",
        userinfo: remote_id_hex,
        host: host,
        port: port
      } ->
        {:ok, __MODULE__.new(host, port, remote_id_hex)}
      %URI{scheme: nil} -> {:error, "Invalid URI"}
      %URI{scheme: scheme} -> {:error, "URI scheme must be enode, got #{scheme}"}
    end
  end

  @doc """
  Calculates distance between two peers.

  ## Examples

      iex> {:ok, peer1} = ExWire.Struct.Peer.from_uri("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@13.84.180.240:30303")
      {:ok,
      %ExWire.Struct.Peer{
        host: "13.84.180.240",
        port: 30303,
        remote_id: <<4, 108, 224, 89, 48, 199, 42, 188, 99, 44, 88, 226, 228, 50, 79, 124, 126, 164, 120, 206, 192, 237, 79, 162, 82, 137, 130, 207, 52, 72, 48, 148, 233, 203, 201, 33, 110, 122, 163, 73, 105, 18, 66, 87, 109, 85, 42, 42, 86, 170, 234, 228, 38, 197, 48, 61, 237, 103, 124, 228, 85, 186, 26, 205, 157>>,
        ident: "6ce059...1acd9d"
      }}
      iex> {:ok, peer2} = ExWire.Struct.Peer.from_uri("enode://30b7ab30a01c124a6cceca36863ece12c4f5fa68e3ba9b0b51407ccc002eeed3b3102d20a88f1c1d3c3154e2449317b8ef95090e77b312d5cc39354f86d5d606@52.176.7.10:30303")
      {:ok,
      %ExWire.Struct.Peer{
         host: "52.176.7.10",
         ident: "30b7ab...d5d606",
         port: 30303,
         remote_id: <<4, 48, 183, 171, 48, 160, 28, 18, 74, 108, 206, 202, 54, 134,
           62, 206, 18, 196, 245, 250, 104, 227, 186, 155, 11, 81, 64, 124, 204, 0,
           46, 238, 211, 179, 16, 45, 32, 168, 143, 28, 29, 60, 49, 84, 226, 68, 147,
           23, 184, 239, 149, 9, 14, 119, 179, 18, 213, 204, 57, 53, 79, 134, 213,
           214, 6>>
      }}
      iex> ExWire.Struct.Peer.distance(peer1, peer2)
      4836423436078365946549741868094714594498094329507634765136070090702808166453086944189931728465215433851189918595312248910582541005005227897546715740183451
  """
  @spec distance(Peer.t(), Peer.t()) :: integer()
  def distance(%Peer{remote_id: remote_id1}, %Peer{remote_id: remote_id2}) do
    remote_int_id1 = remote_id1 |> :binary.decode_unsigned()
    remote_int_id2 = remote_id2 |> :binary.decode_unsigned()

    remote_int_id1 ^^^ remote_int_id2
  end
end

defimpl String.Chars, for: ExWire.Struct.Peer do

  @spec to_string(ExWire.Struct.Peer.t) :: String.t
  def to_string(peer) do
    peer.ident
  end

end
