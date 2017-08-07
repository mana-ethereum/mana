defmodule ExDevp2p.Encoding.Address do
  @moduledoc """
  Helper functions to handle information about
  a sender or receiver's IP address.
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

      iex> ExDevp2p.Encoding.Address.decode(<<1,2,3,4>>, <<>>, <<5>>)
      %ExDevp2p.Encoding.Address{
        ip: [1,2,3,4],
        udp_port: nil,
        tcp_port: 5,
      }
  """
  @spec decode(binary(), binary(), binary()) :: t
  def decode(ip, udp_port, tcp_port) do
    %{
      ip: decode_ip(ip),
      udp_port: decode_port(udp_port),
      tcp_port: decode_port(tcp_port),
    }
  end

  @doc """
  Given an IPv4 address in binary form,
  returns the address in list form.

  ## Examples

      iex> ExDevp2p.Encoding.Address.decode_ip(<<1,2,3,4>>)
      [1,2,3,4]

      iex> ExDevp2p.Encoding.Address.decode_ip(<<0xFF, 0xFF, 0xFF, 0xFF>>)
      [255, 255, 255, 255]

      iex> ExDevp2p.Encoding.Address.decode_ip(<<>>)
      []
  """
  @spec decode_ip(binary()) :: ip
  def decode_ip(data) do
    data
      |> :binary.bin_to_list
      |> List.to_tuple
  end

  @doc """
  Returns a port given a binary version of the port
  as input. Note: we return `nil` for an empty or zero binary.

  ## Examples

      iex> ExDevp2p.Encoding.Address.decode_port(<<>>)
      nil

      iex> ExDevp2p.Encoding.Address.decode_port(<<0>>)
      nil

      iex> ExDevp2p.Encoding.Address.decode_port(<<0, 0>>)
      nil

      iex> ExDevp2p.Encoding.Address.decode_port(<<1>>)
      256

      iex> ExDevp2p.Encoding.Address.decode_port(<<1, 0>>)
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

      iex> ExDevp2p.Encoding.Address.encode(%ExDevp2p.Encoding.Address{ip: [1, 2, 3, 4], udp_port: nil, tcp_port: 5})
      [<<1, 2, 3, 4>>, <<>>, <<5>>]
  """
  @spec encode(t) :: {ip, ip_port | nil, ip_port | nil}
  def encode(%__MODULE__{ip: ip, tcp_port: tcp_port, udp_port: udp_port}) do
    {
      encode_ip(ip),
      encode_port(udp_port),
      encode_port(tcp_port),
    }
  end

  @doc """
  Given an ip address that's an encoded as a list,
  returns that address encoded as a binary.

  ## Examples

      iex> ExDevp2p.Encoding.Address.encode_ip([1, 2, 3, 4])
      <<1, 2, 3, 4>>

      iex> ExDevp2p.Encoding.Address.encode_ip([])
      <<>>
  """
  @spec encode_ip(ip) :: binary()
  def encode_ip(ip) do
    ip
      |> Tuple.to_list
      |> :binary.list_to_bin
  end

  @doc """
  Given a port, returns that port encoded in binary.

  ## Examples

      iex> ExDevp2p.Encoding.Address.encode_port(256)
      <<1, 0>>

      iex> ExDevp2p.Encoding.Address.encode_port(nil)
      <<>>

      iex> ExDevp2p.Encoding.Address.encode_port(0)
      <<>>
  """
  @spec encode_port(ip_port | nil) :: binary()
  def encode_port(port) do
    case port do
      nil -> <<>>
      0 -> <<>>
      _ -> :binary.encode_unsigned(port)
    end
  end
end
