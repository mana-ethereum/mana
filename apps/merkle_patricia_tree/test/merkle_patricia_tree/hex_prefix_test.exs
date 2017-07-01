defmodule MerklePatriciaTree.HexPrefixTest do
  use ExUnit.Case
  alias MerklePatriciaTree.HexPrefix

  test 'converts binary to nibble list' do
    binary = "rock"
    expected_result = [7, 2, 6, 15, 6, 3, 6, 11]

    result = binary |> HexPrefix.to_nibbles

    assert result == expected_result
  end

  test 'encodes nibble list to hex prefix (1)' do
    nibbles = [1, 2, 3, 4, 5]
    expected_result = "\x11\x23\x45"

    result = nibbles |> HexPrefix.encode

    assert_equal result, expected_result
  end

  test 'encodes nibble list to hex prefix (2)' do
    nibbles = [0, 1, 2, 3, 4, 5]
    expected_result = "\x00\x01\x23\x45"

    result = nibbles |> HexPrefix.encode

    assert_equal result, expected_result
  end

  test 'encodes nibble list to hex prefix (3)' do
    nibbles = [0, 15, 1, 12, 11, 8, 16]
    expected_result = "\x20\x0f\x1c\xb8"

    result = nibbles |> HexPrefix.encode

    assert_equal result, expected_result
  end

  test 'encodes nibble list to hex prefix (4)' do
    nibbles = [15, 1, 12, 11, 8, 16]
    expected_result = "\x3f\x1c\xb8"

    result = nibbles |> HexPrefix.encode

    assert_equal result, expected_result
  end

  def assert_equal(bytes, binary) do
    bytes
    |> Enum.reduce(binary, fn(byte, << <<cur_byte>>, tail :: binary >>) ->
      assert byte == cur_byte

      tail
    end)
  end
end
