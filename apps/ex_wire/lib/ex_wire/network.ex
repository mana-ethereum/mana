defmodule ExWire.Network do
  @moduledoc """
  This module will handle the business logic for processing
  incoming messages from the network. We will, for instance,
  decide to respond pong to any incoming ping.
  """

  require Logger

  alias ExWire.Crypto
  alias ExWire.Handler
  alias ExWire.Protocol

  defmodule InboundMessage do
    @moduledoc """
    Struct to define an inbound message from a remote peer
    """

    defstruct [
      data: nil,
      server_pid: nil,
      remote_host: nil,
      timestamp: nil,
    ]

    @type t :: %__MODULE__{
      data: binary(),
      server_pid: pid(),
      remote_host: ExWire.Struct.Endpoint.t,
      timestamp: integer(),
    }
  end

  @type handler_action :: :no_action | {:sent_message, atom()}

  @doc """
  Top-level receiver function to process an incoming message.
  We'll first validate the message, and then pass it to
  the appropriate handler.

  ## Examples

      iex> ping_data = [1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode
      iex> payload = <<0::512>> <> <<0::8>> <> <<1::8>> <> ping_data
      iex> hash = ExWire.Crypto.hash(payload)
      iex> ExWire.Network.receive(%ExWire.Network.InboundMessage{
      ...>   data: hash <> <<0::512>> <> <<0::8>> <> <<1::8>> <> ping_data,
      ...>   server_pid: self(),
      ...>   remote_host: nil,
      ...>   timestamp: 123,
      ...> })
      {:sent_message, ExWire.Message.Pong}

      iex> ping_data = [1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode
      iex> payload = <<0::512>> <> <<0::8>> <> <<1::8>> <> ping_data
      iex> hash = ExWire.Crypto.hash("hello")
      iex> ExWire.Network.receive(%ExWire.Network.InboundMessage{
      ...>   data: hash <> payload,
      ...>   server_pid: self(),
      ...>   remote_host: nil,
      ...>   timestamp: 123,
      ...> })
      ** (ExWire.Crypto.HashMismatch) Invalid hash
  """
  @spec receive(InboundMessage.t) :: handler_action
  def receive(inbound_message=%InboundMessage{data: data, server_pid: _server_pid, remote_host: _remote_host, timestamp: _timestamp}) do
    :ok = assert_integrity(data)

    handle(inbound_message)
  end

  @doc """
  Given the data of an inbound message, we'll run a quick SHA3 sum to verify
  the integrity of the message.

  ## Examples

      iex> ExWire.Network.assert_integrity(ExWire.Crypto.hash("hi mom") <> "hi mom")
      :ok

      iex> ExWire.Network.assert_integrity(<<1::256>> <> "hi mom")
      ** (ExWire.Crypto.HashMismatch) Invalid hash
  """
  @spec assert_integrity(binary()) :: :ok
  def assert_integrity(<< hash :: size(256), payload :: bits >>) do
    Crypto.assert_hash(payload, <<hash::256>>)
  end

  @doc """
  Function to pass message to the appropriate handler. E.g. for a ping
  we'll pass the decoded message to `ExWire.Handlers.Ping.handle/1`.

  ## Examples

      iex> ping_data = [1, [<<1,2,3,4>>, <<>>, <<5>>], [<<5,6,7,8>>, <<6>>, <<>>], 4] |> ExRLP.encode
      iex> ExWire.Network.handle(%ExWire.Network.InboundMessage{
      ...>   data: <<0::256>> <> <<0::512>> <> <<0::8>> <> <<1::8>> <> ping_data,
      ...>   server_pid: self(),
      ...>   remote_host: nil,
      ...>   timestamp: 5,
      ...> })
      {:sent_message, ExWire.Message.Pong}

      iex> ExWire.Network.handle(%ExWire.Network.InboundMessage{
      ...>   data: <<0::256>> <> <<0::512>> <> <<0::8>> <> <<99::8>> <> <<>>,
      ...>   server_pid: self(),
      ...>   remote_host: nil,
      ...>   timestamp: 5,
      ...> })
      :no_action
  """
  @spec handle(InboundMessage.t) :: handler_action
  def handle(%InboundMessage{
    data: <<
      hash :: size(256),
      signature :: size(512),
      recovery_id:: integer-size(8),
      type:: integer-size(8),
      data :: bitstring
    >>,
    server_pid: server_pid,
    remote_host: remote_host,
    timestamp: timestamp,
  }) do
    params = %Handler.Params{
      remote_host: remote_host,
      signature: signature,
      recovery_id: recovery_id,
      hash: hash,
      data: data,
      timestamp: timestamp,
    }

    case Handler.dispatch(type, params) do
      :not_implemented -> :no_action
      :no_response -> :no_action
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
      {:sent_message, ExWire.Message.Pong}
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
  @spec send(ExWire.Message.t, pid(), ExWire.Struct.Endpoint.t) :: handler_action
  def send(message, server_pid, to) do
    GenServer.cast(
      server_pid,
      {
        :send,
        %{
          to: to,
          data: Protocol.encode(message, ExWire.Config.private_key()),
        }
      }
    )

    {:sent_message, message.__struct__}
  end
end
