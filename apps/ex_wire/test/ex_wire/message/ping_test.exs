defmodule ExWire.Message.PingTest do
  use ExUnit.Case, async: true
  doctest ExWire.Message.Ping

  alias ExWire.Message.Ping

  describe "decode/1" do
    test "correctly decodes data" do
      rlp_encoded_binary =
        <<232, 4, 215, 144, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 130, 118, 95, 130,
          118, 95, 201, 132, 58, 136, 8, 186, 130, 51, 216, 128, 132, 88, 115, 40, 205>>

      expected_result = %ExWire.Message.Ping{
        from: %ExWire.Struct.Endpoint{
          ip: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          tcp_port: 30303,
          udp_port: 30303
        },
        timestamp: 1_483_942_093,
        to: %ExWire.Struct.Endpoint{
          ip: [58, 136, 8, 186],
          tcp_port: nil,
          udp_port: 13272
        },
        version: 4
      }

      result = Ping.decode(rlp_encoded_binary)

      assert result == expected_result
    end
  end
end
