defmodule MerklePatriciaTree.Nibbles.HexPrefixTest do
  use ExUnit.Case
  alias MerklePatriciaTree.Nibbles.HexPrefix

  test 'encodes nibble list to hex prefix (1)' do
    nibbles = [1, 2, 3, 4, 5]
    expected_result = "\x11\x23\x45"

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end

  test 'decodes hex prefix encoded nibbles (1)' do
    nibbles = [1, 2, 3, 4, 5]

    result =
      nibbles
      |> HexPrefix.encode
      |> HexPrefix.decode

    assert result == nibbles
  end

  test 'encodes nibble list to hex prefix (2)' do
    nibbles = [0, 1, 2, 3, 4, 5]
    expected_result = "\x00\x01\x23\x45"

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end

  test 'decodes hex prefix encoded nibbles (2)' do
    nibbles = [0, 1, 2, 3, 4, 5]

    result =
      nibbles
      |> HexPrefix.encode
      |> HexPrefix.decode

    assert result == nibbles
  end

  test 'encodes nibble list to hex prefix (3)' do
    nibbles = [0, 15, 1, 12, 11, 8, 16]
    expected_result = "\x20\x0f\x1c\xb8"

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end

  test 'decodes hex prefix encoded nibbles (3)' do
    nibbles = [0, 15, 1, 12, 11, 8]

    result =
      nibbles
      |> HexPrefix.encode
      |> HexPrefix.decode

    assert result == nibbles
  end

  test 'encodes nibble list to hex prefix (4)' do
    nibbles = [15, 1, 12, 11, 8, 16]
    expected_result = "\x3f\x1c\xb8"

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end

  test 'decodes hex prefix encoded nibbles (4)' do
    nibbles = [15, 1, 12, 11, 8, 16]

    result =
      nibbles
      |> HexPrefix.encode
      |> HexPrefix.decode

    assert result == nibbles
  end
end
