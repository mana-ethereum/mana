defmodule Blockchain.Ethash.RandMemoHashTest do
  use ExUnit.Case, async: true

  alias Blockchain.Ethash.RandMemoHash
  alias ExthCrypto.Hash.Keccak

  describe "hash/1" do
    test "returns the rand memo hash of each element in the list" do
      element0 = Keccak.kec512(<<0::256>>)
      element1 = Keccak.kec512(<<1::256>>)
      input = %{0 => element0, 1 => element1}

      result = RandMemoHash.hash(input)

      assert result == %{
               0 =>
                 <<168, 98, 11, 46, 190, 202, 65, 251, 199, 115, 187, 131, 123, 94, 114, 77, 110,
                   178, 222, 87, 13, 153, 133, 141, 240, 215, 217, 112, 103, 251, 129, 3, 178, 23,
                   87, 135, 59, 115, 80, 151, 179, 93, 59, 234, 143, 209, 195, 89, 169, 232, 166,
                   60, 21, 64, 199, 108, 151, 132, 207, 141, 151, 94, 153, 92>>,
               1 =>
                 <<175, 250, 143, 137, 98, 157, 164, 204, 135, 31, 34, 5, 221, 149, 204, 99, 82,
                   235, 66, 117, 245, 198, 54, 34, 237, 239, 52, 189, 54, 181, 205, 179, 153, 86,
                   117, 117, 201, 54, 150, 221, 111, 87, 162, 99, 191, 237, 67, 187, 53, 158, 72,
                   243, 49, 148, 137, 216, 42, 25, 179, 89, 245, 132, 13, 28>>
             }
    end
  end
end
