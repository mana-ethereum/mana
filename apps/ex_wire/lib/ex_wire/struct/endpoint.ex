defmodule ExWire.Struct.Endpoint do
  @moduledoc """
  Struct to represent an endpoint in ExWire.
  """

  defstruct [
    ip: nil,
    udp_port: nil,
    tcp_port: nil
  ]

  @type ip :: [integer()]
  @type ip_port :: integer()

  @type t :: %__MODULE__{
    ip: ip,
    udp_port: ip_port | nil,
    tcp_port: ip_port | nil,
  }

  @doc """
  Returns a struct given an `ip` in binary form, plus an
  `udp_port` or `tcp_port`.

  ## Examples

      iex> ExWire.Struct.Endpoint.decode([<<1,2,3,4>>, <<>>, <<5>>])
      %ExWire.Struct.Endpoint{
        ip: [1,2,3,4],
        udp_port: nil,
        tcp_port: 5,
      }
  """
  @spec decode(ExRLP.t) :: t
  def decode([ip, udp_port, tcp_port]) do
    %__MODULE__{
      ip: decode_ip(ip),
      udp_port: decode_port(udp_port),
      tcp_port: decode_port(tcp_port),
    }
  end

  @doc """
  Given an IPv4 or IPv6 address in binary form,
  returns the address in list form.

  ## Examples

      iex> ExWire.Struct.Endpoint.decode_ip(<<1,2,3,4>>)
      [1, 2, 3, 4]

      iex> ExWire.Struct.Endpoint.decode_ip(<<1::128>>)
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]

      iex> ExWire.Struct.Endpoint.decode_ip(<<0xFF, 0xFF, 0xFF, 0xFF>>)
      [255, 255, 255, 255]

      iex> ExWire.Struct.Endpoint.decode_ip(<<127, 0, 0, 1>>)
      [127, 0, 0, 1]

      iex> ExWire.Struct.Endpoint.decode_ip(<<>>)
      []
  """
  @spec decode_ip(binary()) :: ip
  def decode_ip(data) do
    data
      |> :binary.bin_to_list
  end

  @doc """
  Returns a port given a binary version of the port
  as input. Note: we return `nil` for an empty or zero binary.

  ## Examples

      iex> ExWire.Struct.Endpoint.decode_port(<<>>)
      nil

      iex> ExWire.Struct.Endpoint.decode_port(<<0>>)
      nil

      iex> ExWire.Struct.Endpoint.decode_port(<<0, 0>>)
      nil

      iex> ExWire.Struct.Endpoint.decode_port(<<1>>)
      1

      iex> ExWire.Struct.Endpoint.decode_port(<<1, 0>>)
      256
  """
  def decode_port(data) do
    case :binary.decode_unsigned(data) do
      0 -> nil
      port -> port
    end
  end

  @doc """
  Versus `decode/3`, and given a module with an ip, a tcp_port and
  a udp_port, returns a tuple of encoded values.

  ## Examples

      iex> ExWire.Struct.Endpoint.encode(%ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: nil, tcp_port: 5})
      [<<1, 2, 3, 4>>, <<>>, <<5>>]
  """
  @spec encode(t) :: ExRLP.t
  def encode(%__MODULE__{ip: ip, tcp_port: tcp_port, udp_port: udp_port}) do
    [
      encode_ip(ip),
      encode_port(udp_port),
      encode_port(tcp_port),
    ] |> IO.inspect
  end

  @doc """
  Given an ip address that's an encoded as a list,
  returns that address encoded as a binary.

  ## Examples

      iex> ExWire.Struct.Endpoint.encode_ip([1, 2, 3, 4])
      <<1, 2, 3, 4>>

      iex> ExWire.Struct.Endpoint.encode_ip([])
      <<>>
  """
  @spec encode_ip(ip) :: binary()
  def encode_ip(ip) do
    ip
    |> :binary.list_to_bin
  end

  @doc """
  Given a port, returns that port encoded in binary.

  ## Examples

      iex> ExWire.Struct.Endpoint.encode_port(256)
      <<1, 0>>

      iex> ExWire.Struct.Endpoint.encode_port(nil)
      <<0, 0>>

      iex> ExWire.Struct.Endpoint.encode_port(0)
      <<0, 0>>
  """
  @spec encode_port(ip_port | nil) :: binary()
  def encode_port(port) do
    case port do
      nil -> <<>>
      _ -> port |> :binary.encode_unsigned |> ExthCrypto.Math.pad(2)
    end
  end
end
