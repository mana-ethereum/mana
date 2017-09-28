defmodule ExWire.Framing.FrameTest do
  use ExUnit.Case, async: true
  alias ExWire.Framing.Frame

  test "simple frame test" do
    hash = <<1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1>>
    aes = ExthCrypto.Hash.Keccak(<<>>)
    mac = ExthCrypto.Hash.Keccak(<<>>)
    ingress_mac = hash
    egress_mac = hash

    expected = "00828ddae471818bb0bfa6b551d1cb4201010101010101010101010101010101ba628a4ba590cb43f7848f41c438288501010101010101010101010101010101" |> ExthCrypto.Math.hex_to_bin

    Frame.frame(?, 8, [1, 2, 3, 4])
  end
end