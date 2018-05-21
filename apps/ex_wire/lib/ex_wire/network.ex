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
        <<13, 23, 15, 114, 251, 242, 25, 68, 27, 78, 90, 174, 113, 36, 148, 153, 216,
          148, 187, 100, 15, 207, 119, 208, 4, 207, 139, 124, 116, 223, 190, 119, 253,
          177, 0, 115, 136, 159, 247, 246, 255, 31, 165, 159, 142, 51, 241, 17, 150,
          251, 211, 152, 55, 183, 40, 239, 124, 190, 53, 212, 68, 200, 141, 194, 5, 70,
          187, 184, 56, 127, 78, 182, 140, 7, 9, 0, 149, 238, 13, 117, 233, 210, 130,
          75, 91, 15, 111, 218, 23, 174, 189, 146, 218, 87, 237, 214, 0, 2, 236, 201,
          132, 1, 2, 3, 4, 128, 130, 0, 5, 160, 21, 96, 138, 2, 65, 173, 135, 69, 74,
          35, 153, 190, 41, 48, 2, 173, 239, 44, 221, 207, 63, 116, 210, 103, 215, 10,
          87, 14, 174, 165, 52, 168, 123>>
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
        <<186, 16, 96, 67, 232, 1, 185, 244, 75, 54, 153, 182, 228, 89, 162, 187, 148,
          83, 107, 72, 174, 178, 39, 188, 53, 79, 237, 46, 23, 83, 128, 30, 132, 89,
          76, 186, 158, 17, 193, 10, 32, 11, 133, 71, 74, 2, 12, 55, 145, 203, 212,
          191, 40, 5, 202, 143, 168, 175, 141, 1, 6, 176, 102, 215, 52, 234, 219, 63,
          177, 207, 23, 172, 231, 255, 172, 206, 244, 19, 12, 70, 21, 204, 252, 193,
          87, 79, 107, 0, 28, 179, 239, 159, 96, 16, 11, 135, 1, 2, 204, 201, 132, 1,
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
    params =
      %Handler.Params{
        remote_host: remote_host,
        signature: signature,
        recovery_id: recovery_id,
        hash: hash,
        data: data,
        timestamp: timestamp
      }

    case Handler.dispatch(type, params, options) do
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
