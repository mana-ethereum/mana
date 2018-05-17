defmodule ExWire.Network do
  @moduledoc """
  This module will handle the business logic for processing
  incoming messages from the network. We will, for instance,
  decide to respond pong to any incoming ping.
  """

  require Logger

  alias ExWire.{Crypto, Handler, Protocol, Config, Message}
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
      {
        :sent_message,
        ExWire.Message.Pong,
        <<11, 46, 99, 201, 31, 40, 192, 172, 205, 181, 103, 70, 170, 96, 36, 149, 232,
        23, 150, 18, 130, 228, 250, 64, 5, 96, 194, 18, 45, 143, 235, 63, 62, 71, 59,
        91, 40, 40, 141, 215, 176, 121, 246, 182, 129, 43, 195, 80, 245, 211, 151,
        59, 218, 228, 173, 17, 184, 160, 76, 117, 58, 60, 101, 111, 12, 97, 242, 81,
        171, 51, 168, 201, 224, 171, 181, 123, 180, 19, 129, 124, 89, 64, 255, 132,
        45, 205, 174, 52, 216, 85, 135, 181, 220, 211, 59, 223, 0, 2, 236, 201, 132,
        1, 2, 3, 4, 128, 130, 0, 5, 160, 21, 96, 138, 2, 65, 173, 135, 69, 74, 35,
        153, 190, 41, 48, 2, 173, 239, 44, 221, 207, 63, 116, 210, 103, 215, 10, 87,
        14, 174, 165, 52, 168, 123>>
       }

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
  @spec receive(InboundMessage.t()) :: handler_action
  def receive(
        inbound_message = %InboundMessage{
          data: data,
          server_pid: _server_pid,
          remote_host: _remote_host,
          timestamp: _timestamp
        }
      ) do
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
  def assert_integrity(<<hash::size(256), payload::bits>>) do
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
      {
        :sent_message,
        ExWire.Message.Pong,
        <<33, 93, 10, 200, 46, 235, 5, 24, 6, 132, 70, 23, 191, 109, 80, 251, 204, 47,
        68, 228, 124, 54, 165, 107, 90, 131, 63, 232, 26, 189, 4, 169, 39, 92, 92,
        244, 62, 98, 19, 184, 151, 192, 159, 27, 136, 5, 43, 122, 27, 66, 220, 115,
        103, 184, 180, 211, 214, 146, 185, 110, 78, 78, 19, 24, 106, 132, 223, 233,
        255, 54, 51, 212, 128, 127, 12, 13, 120, 127, 234, 54, 114, 17, 244, 45, 23,
        24, 137, 162, 131, 69, 229, 166, 228, 115, 145, 240, 0, 2, 204, 201, 132, 1,
        2, 3, 4, 128, 130, 0, 5, 128, 5>>
      }

      iex> ExWire.Network.handle(%ExWire.Network.InboundMessage{
      ...>   data: <<0::256>> <> <<0::512>> <> <<0::8>> <> <<99::8>> <> <<>>,
      ...>   server_pid: self(),
      ...>   remote_host: nil,
      ...>   timestamp: 5,
      ...> })
      :no_action
  """
  @spec handle(InboundMessage.t()) :: handler_action
  def handle(%InboundMessage{
        data: <<
          hash::size(256),
          signature::size(512),
          recovery_id::integer-size(8),
          type::integer-size(8),
          data::bitstring
        >>,
        server_pid: server_pid,
        remote_host: remote_host,
        timestamp: timestamp
      }) do
    params = %Handler.Params{
      remote_host: remote_host,
      signature: signature,
      recovery_id: recovery_id,
      hash: hash,
      data: data,
      timestamp: timestamp
    }

    case Handler.dispatch(type, params) do
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
        <<237, 29, 189, 16, 55, 49, 91, 151, 78, 234, 77, 196, 228, 33, 158, 48, 254,
         206, 167, 122, 154, 30, 84, 104, 71, 143, 58, 81, 64, 76, 246, 79, 121, 172,
         184, 160, 58, 90, 92, 96, 90, 238, 168, 181, 121, 50, 213, 131, 209, 241, 51,
         1, 178, 16, 33, 254, 66, 109, 222, 74, 116, 215, 55, 114, 9, 11, 231, 55,
         220, 150, 231, 233, 223, 118, 87, 172, 141, 143, 96, 93, 229, 171, 86, 204,
         22, 3, 56, 0, 45, 122, 141, 213, 246, 179, 139, 241, 1, 2, 204, 201, 132, 1,
         2, 3, 4, 128, 130, 0, 5, 2, 3>>
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

    GenServer.cast(
      server_pid,
      {
        :send,
        %{
          to: to,
          data: encoded_message
        }
      }
    )

    {:sent_message, message.__struct__, encoded_message}
  end
end
