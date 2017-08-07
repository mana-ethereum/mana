defmodule ExDevp2p.Network do
  @moduledoc """
  This module will handle the business logic for processing
  incoming messages from the network. We will, for instance,
  decide to respond pong to any incoming ping.
  """

  require Logger

  alias ExDevp2p.Crypto
  alias ExDevp2p.Handler
  alias ExDevp2p.Protocol

  defmodule InboundMessage do
    @moduledoc """
    Struct to define an inbound message from a remote peer
    """

    defstruct [
      data: nil,
      server_pid: nil,
      remote_host: nil
    ]

    @type t :: %__MODULE__{
      data: binary(),
      server_pid: pid(),
      remote_host: ExDevp2p.Encoding.Address.t,
    }
  end

  @type handler_action :: :no_action | {:sent_message, atom()}

  # TODO: Remove
  @private_key :binary.encode_unsigned(0xd772e3d6a001a38064dd23964dd2836239fa0e6cec8b28972a87460a17210fe9)

  @doc """
  Top-level receiver function to process an incoming message.
  We'll first validate the message, and then pass it to
  the appropriate handler.

  ## Examples

      iex> ExDevp2p.Network.receive(%ExDevp2p.Network.InboundMessage{data: <<1>>, server_pid: 2, remote_host: <<3>>})
      :ok
  """
  def receive(inbound_message=%InboundMessage{data: data, server_pid: _server_pid, remote_host: _remote_host}) do
    :ok = assert_integrity(data)

    handle(inbound_message)
  end

  @doc """
  Given the data of an inbound message, we'll run a quick SHA3 sum to verify
  the integrity of the message.

  ## Examples

      iex> ExDevp2p.Network.assert_integrity(<<1::256>> <> <<2>>)
      :ok

      iex> ExDevp2p.Network.assert_integrity(<<1::256>> <> <<3>>)
      ** (HashMismatch) ok
  """
  @spec assert_integrity(binary()) :: :ok
  def assert_integrity(<< hash :: size(256), payload :: bits >>) do
    Crypto.assert_hash(hash, payload)
  end

  @doc """
  Function to pass message to the appropriate handler. E.g. for a ping
  we'll pass the decoded message to `ExDevp2p.Handlers.Ping.handle/1`.

  # TODO: Add tests
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
  }) do
    params = %Handler.Params{
      remote_host: remote_host,
      signature: signature,
      recovery_id: recovery_id,
      hash: hash,
      data: data
    }

    case Handler.dispatch(type, params) do
      :not_implemented -> :no_action
      :no_response -> :no_action
      response_message ->
        # TODO: Response `message.to` is... duck-typing...
        send(response_message, server_pid, response_message.to)
    end
  end

  @doc """
  Sends a message asynchronously via casting a message
  to our running `gen_server`.

  # TODO: Add tests
  """
  @spec send(ExDevp2p.Message.t, pid(), ExDevp2p.Encoding.Address.t) :: handler_action
  def send(message, server_pid, to) do
    GenServer.cast(
      server_pid,
      {
        :send,
        %{
          to: to,
          data: Protocol.encode(message, @private_key),
        }
      }
    )

    {:sent_message, message.__struct__}
  end
end
