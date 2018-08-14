defmodule Block.HeaderTest do
  use ExUnit.Case, async: true
  doctest Block.Header

  import ExthCrypto.Math, only: [hex_to_bin: 1, hex_to_int: 1]

  alias Block.Header
  alias EVM.EthereumCommonTestsHelper, as: Helper

  @forks_with_block %{
    frontier: 1,
    homestead: 1_150_000,
    dao_fork: 1_920_000,
    eip_150: 2_463_000,
    spurious_dragon: 2_675_000,
    byzantium: 4_370_000
  }

  @next_fork_block_number @forks_with_block[:homestead]

  describe "Difficulty Tests (Ethereum Common Tests)" do
    test "Calculates frontier and homestead difficulties" do
      difficulty_tests()
      |> read_test()
      |> Enum.filter(&forks_to_run/1)
      |> Enum.map(&run_test/1)
      |> Enum.filter(&failed_tests/1)
      |> make_assertion()
    end
  end

  defp forks_to_run({_name, test_data}) do
    hex_to_int(test_data["currentBlockNumber"]) < @next_fork_block_number
  end

  defp filter_test(tests, number) do
    Enum.filter(tests, fn {name, _} -> name == "DifficultyTest#{number}" end)
  end

  defp run_test({name, test_data}) do
    expected_difficulty = hex_to_int(test_data["currentDifficulty"])

    difficulty =
      test_data
      |> build_headers()
      |> get_difficulty()

    {name, expected_difficulty, difficulty}
  end

  defp build_headers(test_data) do
    test_data
    |> build_current_header()
    |> build_parent_header(test_data)
  end

  def build_current_header(test_data) do
    %Header{
      number: hex_to_int(test_data["currentBlockNumber"]),
      timestamp: hex_to_int(test_data["currentTimestamp"])
    }
  end

  def build_parent_header(current_header, test_data) do
    parent_header = %Header{
      number: current_header.number - 1,
      timestamp: hex_to_int(test_data["parentTimestamp"]),
      difficulty: hex_to_int(test_data["parentDifficulty"]),
      ommers_hash: hex_to_bin(test_data["parentUncles"])
    }

    {current_header, parent_header}
  end

  defp get_difficulty({header, parent_header}) do
    Header.get_difficulty(header, parent_header)
  end

  defp make_assertion([]), do: assert(true)
  defp make_assertion(test_results), do: assert(false, failure_message(test_results))

  def failure_message(test_results) do
    total_failed = Enum.count(test_results)

    message =
      test_results
      |> Enum.map(&single_test_failure_message/1)
      |> Enum.join("\n")

    """
    #{message}
    =======================================
    #{total_failed} difficulty tests failed
    """
  end

  defp single_test_failure_message({name, expected, actual}) do
    "[#{name}] expected difficulty: #{expected}, actual: #{actual}"
  end

  defp failed_tests({_name, expected_difficulty, difficulty}) do
    expected_difficulty != difficulty
  end

  defp difficulty_tests do
    # difficultyFrontier.json tests have:
    # Auto-generated Frontier/Homestead chain difficulty tests
    # Why is it called `Frontier`? Who knows
    Helper.basic_tests_path() <> "/difficultyFrontier.json"
  end

  defp read_test(path) do
    path
    |> File.read!()
    |> Poison.decode!()
  end

  test "serialize and deserialize" do
    header = %Header{
      parent_hash: <<1::256>>,
      ommers_hash: <<2::256>>,
      beneficiary: <<3::160>>,
      state_root: <<4::256>>,
      transactions_root: <<5::256>>,
      receipts_root: <<6::256>>,
      logs_bloom: <<>>,
      difficulty: 5,
      number: 1,
      gas_limit: 5,
      gas_used: 3,
      timestamp: 6,
      extra_data: "Hi mom",
      mix_hash: <<7::256>>,
      nonce: <<8::64>>
    }

    assert header ==
             header
             |> Header.serialize()
             |> ExRLP.encode()
             |> ExRLP.decode()
             |> Header.deserialize()
  end

  describe "get_difficulty/6" do
    test "Ropsten's genesis block" do
      header = %Header{number: 0}
      ropsten_init_difficulty = 0x100000
      ropsten_min_difficulty = 0x020000
      ropsten_difficulty_bound_divisor = 0x0800
      homestead_block = 0

      difficulty =
        Header.get_difficulty(
          header,
          nil,
          ropsten_init_difficulty,
          ropsten_min_difficulty,
          ropsten_difficulty_bound_divisor,
          homestead_block
        )

      assert difficulty == 1_048_576
    end

    test "Ropsten's first block" do
      header = %Header{number: 1, timestamp: 1_479_642_530}
      parent = %Header{number: 0, timestamp: 0, difficulty: 1_048_576}
      ropsten_init_difficulty = 0x100000
      ropsten_min_difficulty = 0x020000
      ropsten_difficulty_bound_divisor = 0x0800
      homestead_block = 0

      difficulty =
        Header.get_difficulty(
          header,
          parent,
          ropsten_init_difficulty,
          ropsten_min_difficulty,
          ropsten_difficulty_bound_divisor,
          homestead_block
        )

      assert difficulty == 997_888
    end
  end

  describe "mined_by?/2" do
    test "returns true if the address is the beneficiary" do
      miner_address = <<1, 3, 2>>
      header = %Header{beneficiary: miner_address}

      assert Header.mined_by?(header, miner_address)
    end

    test "returns false if the address is not the beneficiary" do
      miner_address = <<1, 3, 2>>
      header = %Header{beneficiary: <<1, 2, 2>>}

      refute Header.mined_by?(header, miner_address)
    end
  end
end
