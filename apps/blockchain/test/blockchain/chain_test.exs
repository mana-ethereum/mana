defmodule Blockchain.ChainTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Chain

  alias Blockchain.Chain
  alias EVM.Configuration

  describe "after_bomb_delays?/2" do
    test "checks if the block number is after any of the bomb delays were introduced" do
      byzantium_transition = 4_370_000

      chain = Chain.load_chain(:foundation)

      assert Chain.after_bomb_delays?(chain, byzantium_transition)
      assert Chain.after_bomb_delays?(chain, byzantium_transition + 1)
      refute Chain.after_bomb_delays?(chain, byzantium_transition - 1)
    end
  end

  describe "bomb_delay_factor_for_block/2" do
    test "returns the bomb delay for the block number" do
      byzantium_transition = 4_370_000

      chain = Chain.load_chain(:foundation)

      assert 3_000_000 == Chain.bomb_delay_factor_for_block(chain, byzantium_transition)
      assert 3_000_000 == Chain.bomb_delay_factor_for_block(chain, byzantium_transition + 1)
    end
  end

  describe "block_reward_for_block/2" do
    test "returns the block reward based on the block number" do
      byzantium_transition = 4_370_000
      three_eth = 3_000_000_000_000_000_000
      five_eth = 5_000_000_000_000_000_000

      chain = Chain.load_chain(:foundation)

      assert three_eth == Chain.block_reward_for_block(chain, byzantium_transition)
      assert three_eth == Chain.block_reward_for_block(chain, byzantium_transition + 1)
      assert five_eth == Chain.block_reward_for_block(chain, 0)
      assert five_eth == Chain.block_reward_for_block(chain, 1)
    end
  end

  describe "after_homestead?/2" do
    test "checks whether or not a block number is after the homestead transition" do
      homestead_transition = 1_150_000

      chain = Chain.load_chain(:foundation)

      assert Chain.after_homestead?(chain, homestead_transition)
      assert Chain.after_homestead?(chain, homestead_transition + 1)
      refute Chain.after_homestead?(chain, homestead_transition - 1)
    end
  end

  describe "after_byzantium?/2" do
    test "checks whether or not a block number is after the byzatium transition" do
      byzantium_transition = 4_370_000

      chain = Chain.load_chain(:foundation)

      assert Chain.after_byzantium?(chain, byzantium_transition)
      assert Chain.after_byzantium?(chain, byzantium_transition + 1)
      refute Chain.after_byzantium?(chain, byzantium_transition - 1)
    end
  end

  describe "evm_config/2" do
    test "it returns the correct `evm_config` based on block number for mainnet" do
      for {block, expected_configuration} <- %{
            0 => Configuration.Frontier,
            1_149_999 => Configuration.Frontier,
            1_150_000 => Configuration.Homestead,
            2_463_000 => Configuration.TangerineWhistle,
            2_675_000 => Configuration.SpuriousDragon,
            4_370_000 => Configuration.Byzantium,
            4_370_001 => Configuration.Byzantium
          } do
        chain = Chain.load_chain(:foundation)
        assert Chain.evm_config(chain, block).__struct__ == expected_configuration
      end
    end

    test "it returns the correct `evm_config` based on block number for ropsten" do
      for {block, expected_configuration} <- %{
            0 => Configuration.TangerineWhistle,
            10 => Configuration.SpuriousDragon,
            1_700_000 => Configuration.Byzantium
          } do
        chain = Chain.load_chain(:ropsten)
        assert Chain.evm_config(chain, block).__struct__ == expected_configuration
      end
    end
  end
end
