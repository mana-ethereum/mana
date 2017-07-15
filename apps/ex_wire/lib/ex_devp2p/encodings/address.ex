defmodule ExDevp2p.Encodings.Address do
  def decode([ip, udp_port, tcp_port]) do
    %{
      ip: decode_ip(ip),
      udp_port: decode_port(udp_port),
      tcp_port: decode_port(tcp_port)
    }
  end

  def decode_ip(data) do
    data
      |> :binary.bin_to_list
      |> List.to_tuple
  end

  def decode_port(data) do
    value = data
      |> :binary.decode_unsigned
    if value == 0, do: nil, else: value
  end

  def encode(%{ip: ip, tcp_port: tcp_port, udp_port: udp_port}) do
    [encode_ip(ip),
      encode_port(udp_port),
      encode_port(tcp_port)]
  end

  def encode_ip(data) do
    data
      |> Tuple.to_list
      |> :binary.list_to_bin
  end

  def encode_port(data) do
    if data == nil, do: 0, else: data
  end
end
