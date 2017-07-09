defmodule MerklePatriciaTree.NibblesTest do
  use ExUnit.Case
  alias MerklePatriciaTree.Nibbles

  test 'converts binary to nibble list' do
    binary = "rock"
    expected_result = [7, 2, 6, 15, 6, 3, 6, 11]

    result = binary |> Nibbles.from_binary

    assert result == expected_result
  end

  test 'convers nibble list to binary' do
    nibble_list = [7, 2, 6, 15, 6, 3, 6, 11]
    expected_result = "rock"

    result = nibble_list |> Nibbles.to_binary

    assert result == expected_result
  end

  test 'encodes nibbles tp hex prefix representation' do
    nibbles = [1, 2, 3, 4, 5]
    expected_result = "\x11\x23\x45"

    result = nibbles |> Nibbles.hex_prefix_encode

    assert result == expected_result
  end

  test 'decodes hex prefix encoded binary to nibbles' do
    binary = "\x11\x23\x45"
    expected_result = [1, 2, 3, 4, 5]

    result = binary |> Nibbles.hex_prefix_decode

    assert result == expected_result
  end

  test 'adds terminator' do
    nibble_list = [1, 5]
    expected_result = [1, 5, 16]

    result = nibble_list |> Nibbles.add_terminator

    assert result == expected_result
  end

  test 'removes terminator' do
    nibble_list = [11, 15, 16]
    expected_result = [11, 15]

    result = nibble_list |> Nibbles.remove_terminator

    assert result == expected_result
  end

  test 'calculates common length prefix (1)' do
    nibbles1 = [1, 2, 5, 9]
    nibbles2 = [1, 2, 5, 10]

    length = Nibbles.common_prefix_length(nibbles1, nibbles2)

    assert length == 3
  end

  test 'calculates common length prefix (2)' do
    nibbles1 = [5, 1, 2, 5, 10]
    nibbles2 = [1, 2, 5, 10]

    length = Nibbles.common_prefix_length(nibbles1, nibbles2)

    assert length == 0
  end
end
