defmodule ExDevp2p.Handler.Ping do
  @moduledoc """
  Module to handle a respond to a Ping message, which generate a Pong response.
  """

  alias ExDevp2p.Handler
  alias ExDevp2p.Message.Pong
  alias ExDevp2p.Message.Ping
  alias ExDevp2p.Util.Timestamp

  @doc """
  Handler for a Ping message.

  ## Examples

      iex> ExDevp2p.Handler.Ping.handle(%{
      ...>   remote_host: %ExDevp2p.Encoding.Address{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: 2,
      ...>   recovery_id: 3,
      ...>   hash: <<5>>,
      ...>   data: <<6>>,
      ...> })
      %ExDevp2p.Messages.Pong{}
  """
  @spec handle(Handler.Params.t) :: Handler.handler_response
  def handle(params) do
    ping = Ping.decode(params.data)

    %Pong{
      to: ping.from,
      hash: params.hash,
      timestamp: Timestamp.now()
    }
  end

end