defmodule ExRLP.DecoderTest do
  use ExUnit.Case
  alias ExRLP.Decoder

  test "decodes empty string" do
    rlp_binary = "80"
    expected_result = ""

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 00" do
    rlp_binary = "00"
    expected_result = "\u0000"

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 01" do
    rlp_binary = "01"
    expected_result = "\u0001"

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 7f" do
    rlp_binary = "7f"
    expected_result = "\u007F"

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end
end
