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

  test "decodes short string (1)" do
    rlp_binary = "83646f67"
    expected_result = "dog"

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes short string (2)" do
    rlp_binary = "b74c6f72656d20697073756d20646f6c6f722073697" <>
      "420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"
    expected_result = "Lorem ipsum dolor sit amet, consectetur adipisicing eli"

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end
end
