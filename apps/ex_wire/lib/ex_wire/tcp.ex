defmodule ExWire.TCP do
  @moduledoc """
  Module to define convenience functions that interact with :gen_tcp and :inet
  """

  @spec listen(integer()) :: {:ok, port()} | {:error, any()}
  def listen(port_number) do
    :gen_tcp.listen(port_number, [:binary, active: false])
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
end
