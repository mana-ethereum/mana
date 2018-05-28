defmodule ExWire.NetworkTest do
  use ExUnit.Case, async: true
  doctest ExWire.Network

  alias ExWire.{Crypto, Network}
  alias ExWire.Struct.Endpoint
  alias ExWire.Network.InboundMessage
  alias ExWire.Message.Pong

  describe "receive/2" do
    test "fails to receive message" do
      ping_data =
        [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode()

      payload = <<0::512>> <> <<0::8>> <> <<1::8>> <> ping_data
      hash = ExWire.Crypto.hash("hello")

      assert_raise ExWire.Crypto.HashMismatch, fn ->
        Network.receive(%InboundMessage{
          data: hash <> payload,
          server_pid: self(),
          remote_host: nil,
          timestamp: 123
        })
      end
    end

    test "sends a message" do
      ping_data =
        [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode()

      signature =
        <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63, 232, 67, 152, 216, 249,
          89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152, 134, 149, 220, 73, 198, 29, 93, 218,
          123, 50, 70, 8, 202, 17, 171, 67, 245, 70, 235, 163, 158, 201, 246, 223, 114, 168, 7, 7,
          95, 9, 53, 165, 8, 177, 13>>

      payload = signature <> <<0::8>> <> <<1::8>> <> ping_data
      hash = Crypto.hash(payload)

      result =
        Network.receive(%InboundMessage{
          data: hash <> payload,
          server_pid: self(),
          remote_host: %Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
          timestamp: 123
        })

      expected_result =
        {:sent_message, Pong,
         <<155, 139, 103, 130, 146, 244, 198, 255, 210, 125, 212, 28, 32, 189, 172, 204, 96, 215,
           178, 205, 207, 229, 9, 16, 121, 111, 193, 156, 159, 91, 172, 105, 172, 137, 117, 170,
           204, 236, 147, 168, 244, 72, 39, 118, 96, 204, 28, 109, 198, 141, 108, 93, 255, 169,
           224, 38, 128, 78, 15, 172, 186, 155, 44, 67, 125, 190, 13, 23, 160, 232, 74, 35, 237,
           213, 81, 96, 115, 141, 124, 14, 189, 16, 223, 179, 38, 92, 147, 167, 53, 190, 70, 73,
           180, 64, 22, 131, 0, 2, 236, 201, 132, 1, 2, 3, 4, 128, 130, 0, 5, 160, 132, 76, 21,
           91, 100, 15, 7, 2, 197, 104, 104, 206, 181, 27, 233, 245, 195, 39, 69, 121, 45, 103,
           153, 123, 23, 144, 94, 46, 153, 122, 226, 111, 123>>}

      assert result == expected_result
    end
  end

  describe "handle/2" do
    test "handle not existing action" do
      result =
        Network.handle(%InboundMessage{
          data: <<0::256>> <> <<0::512>> <> <<0::8>> <> <<99::8>> <> <<>>,
          server_pid: self(),
          remote_host: nil,
          timestamp: 5
        })

      assert result == :no_action
    end

    test "handles ping message" do
      ping_data =
        [1, [<<1, 2, 3, 4>>, <<>>, <<5>>], [<<5, 6, 7, 8>>, <<6>>, <<>>], 4] |> ExRLP.encode()

      signature =
        <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63, 232, 67, 152, 216, 249,
          89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152, 134, 149, 220, 73, 198, 29, 93, 218,
          123, 50, 70, 8, 202, 17, 171, 67, 245, 70, 235, 163, 158, 201, 246, 223, 114, 168, 7, 7,
          95, 9, 53, 165, 8, 177, 13>>

      payload = signature <> <<0::8>> <> <<1::8>> <> ping_data
      hash = Crypto.hash(payload)

      result =
        Network.handle(%InboundMessage{
          data: hash <> payload,
          server_pid: self(),
          remote_host: %Endpoint{ip: [1, 2, 3, 4], udp_port: 55},
          timestamp: 123
        })

      expected_result =
        {:sent_message, Pong,
         <<155, 139, 103, 130, 146, 244, 198, 255, 210, 125, 212, 28, 32, 189, 172, 204, 96, 215,
           178, 205, 207, 229, 9, 16, 121, 111, 193, 156, 159, 91, 172, 105, 172, 137, 117, 170,
           204, 236, 147, 168, 244, 72, 39, 118, 96, 204, 28, 109, 198, 141, 108, 93, 255, 169,
           224, 38, 128, 78, 15, 172, 186, 155, 44, 67, 125, 190, 13, 23, 160, 232, 74, 35, 237,
           213, 81, 96, 115, 141, 124, 14, 189, 16, 223, 179, 38, 92, 147, 167, 53, 190, 70, 73,
           180, 64, 22, 131, 0, 2, 236, 201, 132, 1, 2, 3, 4, 128, 130, 0, 5, 160, 132, 76, 21,
           91, 100, 15, 7, 2, 197, 104, 104, 206, 181, 27, 233, 245, 195, 39, 69, 121, 45, 103,
           153, 123, 23, 144, 94, 46, 153, 122, 226, 111, 123>>}

      assert result == expected_result
    end
  end
end
