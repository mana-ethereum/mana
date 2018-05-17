defmodule ExWire.Handler.Ping do
  @moduledoc """
  Module to handle a respond to a Ping message, which generate a Pong response.
  """

  alias ExWire.Handler
  alias ExWire.Message.{Pong, Ping}

  @doc """
  Handler for a Ping message.

  ## Examples

      iex> ExWire.Handler.Ping.handle(%ExWire.Handler.Params{
      ...>   remote_host: %ExWire.Struct.Endpoint{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: 2,
      ...>   recovery_id: 3,
      ...>   hash: <<5>>,
      ...>   data: [1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
      ...>   timestamp: 123,
      ...> })
      %ExWire.Message.Pong{
        hash: <<5>>,
        timestamp: 123,
        to: %ExWire.Struct.Endpoint{
          ip: [1, 2, 3, 4],
          tcp_port: 5,
          udp_port: nil
        }
      }
  """
  @spec handle(Handler.Params.t()) :: Handler.handler_response()
  def handle(params) do
    ping = Ping.decode(params.data)

    %Pong{
      to: ping.from,
      hash: params.hash,
      timestamp: params.timestamp
    }
  end
end
