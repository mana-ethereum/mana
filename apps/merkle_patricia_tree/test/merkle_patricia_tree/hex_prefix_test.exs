defmodule MerklePatriciaTree.HexPrefixTest do
  use ExUnit.Case
  alias MerklePatriciaTree.HexPrefix

  test 'encodes nibble list to hex prefix (1)' do
    nibbles = [1, 2, 3, 4, 5]
    expected_result = '\x11\x23\x45'

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end

  test 'encodes nibble list to hex prefix (2)' do
    nibbles = [0, 1, 2, 3, 4, 5]
    expected_result = '\x00\x01\x23\x45'

    result = nibbles |> HexPrefix.encode

    assert result == expected_result
  end
end
