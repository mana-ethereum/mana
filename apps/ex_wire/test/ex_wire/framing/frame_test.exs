defmodule ExWire.Framing.FrameTest do
  use ExUnit.Case, async: true
  alias ExWire.Framing.Frame
  alias ExthCrypto.AES

  test "mac encoder" do
    mac_secret = "2212767d793a7a3d66f869ae324dd11bd17044b82c9f463b8a541a4d089efec5" |> ExthCrypto.Math.hex_to_bin
    input_1 = "12532abaec065082a3cf1da7d0136f15" |> ExthCrypto.Math.hex_to_bin
    input_2 = "7e99f682356fdfbc6b67a9562787b18a" |> ExthCrypto.Math.hex_to_bin
    expected_1 = "89464c6b04e7c99e555c81d3f7266a05"
    expected_2 = "85c070030589ef9c7a2879b3a8489316"

    mac_encoder = {ExthCrypto.AES, ExthCrypto.AES.block_size, :ecb}

    assert expected_1 == ExthCrypto.Cipher.encrypt(input_1, mac_secret, mac_encoder) |> Binary.take(-16) |> ExthCrypto.Math.bin_to_hex
    assert expected_2 == ExthCrypto.Cipher.encrypt(input_2, mac_secret, mac_encoder) |> Binary.take(-16) |> ExthCrypto.Math.bin_to_hex
  end

  test "simple frame test read / write" do
    hash = <<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>
    symmetric_key = ExthCrypto.Hash.Keccak.kec(<<>>)
    mac_secret = ExthCrypto.Hash.Keccak.kec(<<>>)
    ingress_mac = ExthCrypto.MAC.init(:fake, [hash])
    egress_mac = ExthCrypto.MAC.init(:fake, [hash])

    secrets = %ExWire.Framing.Secrets{
      egress_mac: ingress_mac,
      ingress_mac: egress_mac,
      mac_encoder: {AES, AES.block_size, :ecb},
      mac_secret: mac_secret,
      encoder_stream: AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>),
      decoder_stream: AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)
    }

    {frame, _updated_secrets} = Frame.frame(8, [1, 2, 3, 4], secrets)

    assert frame |> ExthCrypto.Math.bin_to_hex == "00828ddae471818bb0bfa6b551d1cb4201010101010101010101010101010101ba628a4ba590cb43f7848f41c438288501010101010101010101010101010101"

    {:ok, packet_type, packet_data, frame_rest, _secrets} = Frame.unframe(frame <> "hello", secrets)

    assert frame_rest == "hello"
    assert packet_type == 8
    assert packet_data == [<<1>>, <<2>>, <<3>>, <<4>>]
  end

end