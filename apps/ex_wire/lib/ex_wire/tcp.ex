defmodule ExWire.TCP do
  @moduledoc """
  Module to define convenience functions that interact with :gen_tcp and :inet
  """

  @spec listen(integer()) :: {:ok, port()} | {:error, any()}
  def listen(port_number) do
    :gen_tcp.listen(port_number, [:binary, active: false, reuseaddr: true])
  end

  @spec accept_connection(port()) :: {:ok, port()} | {:error, any()}
  def accept_connection(socket) do
    :gen_tcp.accept(socket)
  end

  @spec hand_over_control(port(), pid()) :: :ok | {:error, any()}
  def hand_over_control(socket, pid) do
    :gen_tcp.controlling_process(socket, pid)
  end

  @spec accept_messages(port()) :: :ok | {:error, any()}
  def accept_messages(socket) do
    :inet.setopts(socket, active: true)
  end

  @spec send_data(port(), binary()) :: :ok | {:error, any()}
  def send_data(socket, data) do
    :gen_tcp.send(socket, data)
  end

  @spec shutdown(port()) :: :ok | {:error, any()}
  def shutdown(socket) do
    :gen_tcp.shutdown(socket, :read_write)
  end

  @spec connect(binary(), integer()) :: {:ok, port()} | {:error, any()}
  def connect(host, port_number) do
    :gen_tcp.connect(String.to_charlist(host), port_number, [:binary])
  end

  @spec peer_info(port()) :: {binary(), integer()}
  def peer_info(socket) do
    {:ok, {host_tuple, port}} = :inet.peername(socket)
    host = host_tuple |> :inet.ntoa() |> to_string()

    {host, port}
  end
end
