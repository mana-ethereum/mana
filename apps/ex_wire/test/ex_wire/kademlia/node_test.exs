defmodule ExWire.Kademlia.NodeTest do
  use ExUnit.Case, async: true
  doctest ExWire.Kademlia.Node

  alias ExthCrypto.{Math, Key}
  alias ExWire.Message

  describe "from_handler_params/1" do
    test "recovers the same public key as from enode uri" do
      public_key =
        "enode://865a63255b3bb68023b6bffd5095118fcc13e79dcf014fe4e47e065c350c7cc72af2e53eff895f11ba1bbb6a2b33271c1116ee870f266618eadfc2e78aa7349c@52.176.100.77:30303"
        |> public_key_from_uri

      # pong params
      params = %ExWire.Handler.Params{
        data:
          <<240, 201, 132, 52, 176, 100, 77, 130, 118, 95, 128, 160, 29, 65, 41, 50, 198, 147,
            127, 73, 177, 80, 239, 246, 180, 189, 173, 74, 105, 76, 61, 217, 3, 34, 13, 206, 26,
            73, 85, 111, 37, 96, 197, 33, 132, 91, 4, 14, 87>>,
        hash:
          <<45, 254, 166, 0, 239, 248, 240, 32, 135, 97, 99, 23, 81, 66, 111, 84, 109, 244, 96,
            14, 144, 192, 175, 70, 166, 211, 145, 24, 240, 206, 138, 52>>,
        recovery_id: 0,
        remote_host: %ExWire.Struct.Endpoint{
          ip: {52, 176, 100, 77},
          tcp_port: nil,
          udp_port: 30303
        },
        signature:
          <<25, 156, 98, 35, 222, 28, 223, 231, 188, 210, 75, 92, 206, 83, 84, 245, 146, 193, 40,
            16, 225, 193, 229, 49, 1, 73, 244, 206, 72, 19, 248, 242, 127, 71, 175, 77, 189, 57,
            252, 157, 18, 164, 186, 166, 160, 0, 64, 8, 246, 32, 106, 130, 127, 189, 97, 62, 29,
            234, 124, 159, 132, 145, 159, 197>>,
        timestamp: 1_526_992_431,
        type: 2
      }

      recovered_public_key =
        Message.recover_public_key(
          <<params.type>> <> params.data,
          params.signature,
          params.recovery_id
        )

      assert public_key == recovered_public_key
    end
  end

  defp public_key_from_uri(uri) do
    uri
    |> parse_public_key()
    |> Math.hex_to_bin()
    |> Key.raw_to_der()
  end

  defp parse_public_key(uri) do
    %URI{
      scheme: "enode",
      userinfo: public_key,
      host: _remote_host,
      port: _remote_peer_port
    } = URI.parse(uri)

    public_key
  end
end
