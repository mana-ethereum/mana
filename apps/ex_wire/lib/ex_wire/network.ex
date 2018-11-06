defmodule ExWire.Network do
  @moduledoc """
  This module will handle the business logic for processing incoming messages
  from the network. We will, for instance, decide to respond pong to any
  incoming ping.
  """

  require Logger

  alias ExWire.{Config, Crypto, Handler, Message, Protocol}
  alias ExWire.Struct.Endpoint

  defmodule InboundMessage do
    @moduledoc """
    Struct to define an inbound message from a remote peer
    """

    defstruct data: nil,
              server_pid: nil,
              remote_host: nil,
              timestamp: nil

    @type t :: %__MODULE__{
            data: binary(),
            server_pid: pid(),
            remote_host: Endpoint.t(),
            timestamp: integer()
          }
  end

  @type handler_action :: :no_action | {:sent_message, atom(), binary()}

  @doc """
  Top-level receiver function to process an incoming message.
  We'll first validate the message, and then pass it to
  the appropriate handler.
  """
  @spec receive(InboundMessage.t(), Keyword.t()) :: handler_action
  def receive(
        inbound_message = %InboundMessage{
          data: data,
          server_pid: _server_pid,
          remote_host: _remote_host,
          timestamp: _timestamp
        },
        options \\ []
      ) do
    :ok = assert_integrity(data)

    handle(inbound_message, options)
  end

  @doc """
  Given the data of an inbound message, we'll run a quick SHA3 sum to verify
  the integrity of the message.

  ## Examples

      iex> ExWire.Network.assert_integrity(ExWire.Crypto.hash("hi mom") <> "hi mom")
      :ok

      iex> ExWire.Network.assert_integrity(<<1::256>> <> "hi mom")
      ** (ExWire.Crypto.HashMismatchError) Invalid hash
  """
  @spec assert_integrity(binary()) :: :ok
  def assert_integrity(<<hash::size(256), payload::bits>>) do
    Crypto.assert_hash(payload, <<hash::256>>)
  end

  @doc """
  Function to pass message to the appropriate handler. E.g. for a ping
  we'll pass the decoded message to `ExWire.Handlers.Ping.handle/1`.
  """
  @spec handle(InboundMessage.t(), Keyword.t()) :: handler_action
  def handle(
        %InboundMessage{
          data: <<
            hash::binary-size(32),
            signature::binary-size(64),
            recovery_id::integer-size(8),
            type::integer-size(8),
            data::bitstring
          >>,
          server_pid: server_pid,
          remote_host: remote_host,
          timestamp: timestamp
        },
        options \\ []
      ) do
    params = %Handler.Params{
      remote_host: remote_host,
      signature: signature,
      recovery_id: recovery_id,
      hash: hash,
      data: data,
      type: type,
      timestamp: timestamp
    }

    case Handler.dispatch(params, options) do
      :not_implemented ->
        :no_action

      :no_response ->
        :no_action

      response_message ->
        # TODO: This is a simple way to determine who to send the message to,
        #       but we may want to revise.
        to = response_message.__struct__.to(response_message) || remote_host

        send(response_message, server_pid, to)
    end
  end

  @doc """
  Sends a message asynchronously via casting a message
  to our running `gen_server`.

  ## Examples

      iex> message = %ExWire.Message.Pong{
      ...>   to: %ExWire.Struct.Endpoint{ip: [1, 2, 3, 4], tcp_port: 5, udp_port: nil},
      ...>   hash: <<2>>,
      ...>   timestamp: 3,
      ...> }
      iex> ExWire.Network.send(message, self(), %ExWire.Struct.Endpoint{ip: <<1, 2, 3, 4>>, udp_port: 5})
      {
        :sent_message,
        ExWire.Message.Pong,
       <<10, 59, 95, 84, 240, 108, 73, 194, 59, 42, 197, 105, 225, 76, 170, 249, 158,
         110, 59, 200, 37, 244, 17, 53, 103, 169, 153, 175, 78, 170, 111, 166, 44, 80,
         242, 22, 34, 174, 202, 103, 15, 75, 121, 18, 195, 130, 58, 145, 196, 52, 165,
         40, 145, 100, 195, 153, 69, 90, 185, 130, 61, 66, 38, 148, 26, 254, 41, 250,
         203, 88, 21, 119, 203, 111, 167, 199, 28, 82, 248, 210, 251, 87, 122, 235,
         239, 178, 185, 81, 231, 218, 114, 34, 91, 153, 141, 57, 1, 2, 204, 201, 132,
         1, 2, 3, 4, 128, 130, 0, 5, 2, 3>>
      }
      iex> receive do m -> m end
      {:"$gen_cast",
        {:send,
          %{
            data: ExWire.Protocol.encode(message, ExWire.Config.private_key()),
            to: %ExWire.Struct.Endpoint{
              ip: <<1, 2, 3, 4>>,
              tcp_port: nil,
              udp_port: 5}
          }
        }
      }
  """
  @spec send(Message.t(), pid(), Endpoint.t()) :: handler_action
  def send(message, server_pid, to) do
    encoded_message = Protocol.encode(message, Config.private_key())

    GenServer.cast(server_pid, {
      :send,
      %{
        to: to,
        data: encoded_message
      }
    })

    {:sent_message, message.__struct__, encoded_message}
  end
end
