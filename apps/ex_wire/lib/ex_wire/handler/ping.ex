defmodule ExWire.Handler.Ping do
  @moduledoc """
  Module to handle a respond to a Ping message, which generate a Pong response.
  """

  alias ExWire.{Handler, Kademlia}
  alias ExWire.Message.{Pong, Ping}

  @doc """
  Handler for a Ping message.

  ## Examples

      iex> ExWire.Handler.Ping.handle(%ExWire.Handler.Params{
      ...>  remote_host: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
      ...>  signature:
      ...>    <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63, 232, 67, 152, 216, 249,
      ...>      89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152, 134, 149, 220, 73, 198, 29, 93,
      ...>      218, 123, 50, 70, 8, 202, 17, 171, 67, 245, 70, 235, 163, 158, 201, 246, 223, 114,
      ...>      168, 7, 7, 95, 9, 53, 165, 8, 177, 13>>,
      ...>  recovery_id: 1,
      ...>  hash: <<5>>,
      ...>  data:
      ...>    [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
      ...>  timestamp: 123,
      ...>  type: 1
      ...>})
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
  @spec handle(Handler.Params.t(), Keyword.t()) :: Handler.handler_response()
  def handle(params, options \\ []) do
    ping = Ping.decode(params.data)

    Kademlia.handle_ping(params, process_name: options[:kademlia_process_name])

    %Pong{
      to: ping.from,
      hash: params.hash,
      timestamp: params.timestamp
    }
  end
end
