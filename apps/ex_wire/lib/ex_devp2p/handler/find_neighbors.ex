defmodule ExDevp2p.Handler.FindNeighbors do
  @moduledoc """
  Not currently implemented.
  """

  alias ExDevp2p.Handler

  @doc """
  Handler for a FindNeighbors message.

  ## Examples

      iex> ExDevp2p.Handler.FindNeighbors.handle(%{
      ...>   remote_host: %ExDevp2p.Encoding.Address{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: 2,
      ...>   recovery_id: 3,
      ...>   hash: <<5>>,
      ...>   data: <<6>>,
      ...> })
      nil
  """
  @spec handle(Handler.Params.t) :: Handler.handler_response
  def handle(%{
    remote_host: _remote_host,
    signature: _signature,
    recovery_id: _recovery_id,
    pid: _pid,
    hash: _hash,
    data: _data
  }) do
    :not_implemented
  end

end