defmodule Blockchain.Account.AddressTest do
  use ExUnit.Case, async: true

  doctest Blockchain.Account.Address

  alias Blockchain.Account.Address

  @hex_address_in_block_177610 "00bca629f698d95a3ab6a2b379cac78c952eb75c"
  @int_address_in_block_177610 4_207_015_016_149_197_627_205_197_234_001_106_133_891_069_788

  describe "new/2" do
    test "generates a new address from an address and nonce" do
      sender = <<0x02::160>>

      expected_address =
        <<30, 208, 147, 166, 216, 88, 183, 173, 67, 180, 70, 173, 88, 244, 201, 236, 9, 101, 145,
          49>>

      address = Address.new(sender, 3)

      assert address == expected_address
    end
  end

  describe "from/1" do
    test "returns same binary if it is 160 bit binary" do
      raw = <<1::160>>

      address = Address.from(raw)

      assert address == raw
    end

    test "pads a binary if it is less than 160 bits" do
      raw = <<1, 2, 3>>

      address = Address.from(raw)

      assert address == :binary.copy(<<0>>, 17) <> raw
    end

    test "raises if binary has more than 160 bits" do
      raw = <<1::168>>

      assert_raise(RuntimeError, "Binary too long for padding", fn -> Address.from(raw) end)
    end

    test "takes an integer and returns a 160 bit encoded/unsigned binary" do
      raw = @int_address_in_block_177610
      expected = Base.decode16!(@hex_address_in_block_177610, case: :lower)

      address = Address.from(raw)

      assert address == expected
    end
  end
end
