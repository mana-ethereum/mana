defmodule EthCore.Block.Header.ValidationTest do
  use ExUnit.Case

  doctest EthCore.Block.Header.Validation

  alias EthCore.Block.Header.Validation

  describe "valid_gas_limit?/4" do
    test "validates gas limit" do
      assert Validation.valid_gas_limit?(1_000_000, nil, 1024, 125_000) == true
      assert Validation.valid_gas_limit?(1_000, nil, 1024, 125_000) == false
      assert Validation.valid_gas_limit?(1_000_000, 1_000_000, 1024, 125_000) == true
      assert Validation.valid_gas_limit?(1_000_000, 2_000_000, 1024, 125_000) == false
      assert Validation.valid_gas_limit?(1_000_000, 500_000, 1024, 125_000) == false
      assert Validation.valid_gas_limit?(1_000_000, 999_500, 1024, 125_000) == true
      assert Validation.valid_gas_limit?(1_000_000, 999_000, 1024, 125_000) == false
      assert Validation.valid_gas_limit?(1_000_000, 2_000_000, 1, 125_000) == true
      assert Validation.valid_gas_limit?(1_000, nil, 1024, 500) == true
    end
  end
end
