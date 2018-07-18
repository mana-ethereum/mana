defmodule ExWire.Handler do
  @moduledoc """
  Defines a behavior for all message handlers of RLPx messages.

  Message handlers tell us how we should respond to a given incoming transmission,
  after it has been decoded.
  """

  alias ExWire.{Message, Crypto}
  alias ExWire.Struct.Endpoint
  alias ExWire.Handler.{Ping, Pong, FindNeighbours, Neighbours}

  require Logger

  @handlers %{
    0x01 => Ping,
    0x02 => Pong,
    0x03 => FindNeighbours,
    0x04 => Neighbours
  }

  defmodule Params do
    @moduledoc "Struct to store parameters from an incoming message"

    defstruct remote_host: nil,
              signature: nil,
              recovery_id: nil,
              hash: nil,
              data: nil,
              timestamp: nil,
              type: nil

    @type t :: %__MODULE__{
            remote_host: Endpoint.t(),
            signature: Crypto.signature(),
            recovery_id: Crypto.recovery_id(),
            hash: Crypto.hash(),
            data: binary(),
            timestamp: integer(),
            type: integer()
          }
  end

  @type handler_response :: :not_implented | :no_response | Message.t()
  @callback handle(Params.t()) :: handler_response

  @doc """
  Decides which module to route the given message to,
  or returns `:not_implemented` if we have no implemented
  a handler for the message type.

  ## Examples

      iex> ExWire.Handler.dispatch(%ExWire.Handler.Params{
      ...>  remote_host: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
      ...>  signature:
      ...>    <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63, 232, 67, 152, 216, 249,
      ...>      89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152, 134, 149, 220, 73, 198, 29, 93,
      ...>      218, 123, 50, 70, 8, 202, 17, 171, 67, 245, 70, 235, 163, 158, 201, 246, 223, 114,
      ...>      168, 7, 7, 95, 9, 53, 165, 8, 177, 13>>,
      ...>  recovery_id: 1,
      ...>  hash: <<5>>,
      ...>  data: [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode(),
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

      iex> ExWire.Handler.dispatch(%ExWire.Handler.Params{type: 99})
      :not_implemented

      # TODO: Add a `no_response` test case
  """
  @spec dispatch(Params.t(), Keyword.t()) :: handler_response
  def dispatch(params, options \\ []) do
    case @handlers[params.type] do
      nil ->
        Logger.warn("Message code `#{inspect(params.type, base: :hex)}` not implemented")
        :not_implemented

      mod when is_atom(mod) ->
        apply(mod, :handle, [params, options])
    end
  end
end
