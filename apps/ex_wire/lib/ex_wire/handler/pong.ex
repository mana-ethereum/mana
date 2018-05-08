defmodule ExWire.Handler.Pong do
  @moduledoc """
  Module to handle a response to a Pong message, which is to do nothing.
  """

  alias ExWire.Handler
  alias ExWire.Message.Pong

  @doc """
  Handler for a Pong message.

  ## Examples

      iex> ExWire.Handler.Pong.handle(%ExWire.Handler.Params{
      ...>   remote_host: %ExWire.Struct.Endpoint{ip: [1,2,3,4], udp_port: 55},
      ...>   signature: 2,
      ...>   recovery_id: 3,
      ...>   hash: <<5>>,
      ...>   data: [[<<1,2,3,4>>, <<>>, <<5>>], <<2>>, 3] |> ExRLP.encode(),
      ...>   timestamp: 123,
      ...> })
      :no_response
  """
  @spec handle(Handler.Params.t()) :: Handler.handler_response()
  def handle(params) do
    _pong = Pong.decode(params.data)

    # TODO: Add to K-Bucket

    :no_response
  end
end
