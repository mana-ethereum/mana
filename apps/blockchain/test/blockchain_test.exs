defmodule BlockchainTest do
  use ExUnit.Case

  import EthCommonTest.Helpers

  alias Blockchain.Chain
  alias EthCommonTest.BlockchainTestRunner

  doctest Blockchain

  @failing_constantinople_tests File.read!(
                                  System.cwd() <> "/test/support/constantinople_failing_tests.txt"
                                )

  @failing_tests %{
    "Frontier" => [],
    "Homestead" => [],
    "HomesteadToDaoAt5" => [],
    "TangerineWhistle" => [],
    "SpuriousDragon" => [],
    "Byzantium" => [],
    "Constantinople" => String.split(@failing_constantinople_tests, "\n"),
    # the rest are not implemented yet
    "EIP158ToByzantiumAt5" => [],
    "FrontierToHomesteadAt5" => [],
    "HomesteadToEIP150At5" => []
  }

  @ten_minutes 1000 * 60 * 10

  # Run each fork as its own test
  @tag :ethereum_common_tests
  @tag :Frontier
  test "runs Frontier blockchain tests", do: run_fork_tests("Frontier")

  @tag :ethereum_common_tests
  @tag :Homestead
  test "runs Homestead blockchain tests", do: run_fork_tests("Homestead")

  @tag :ethereum_common_tests
  @tag :HomesteadToDaoAt5
  test "runs HomesteadToDaoAt5 blockchain tests", do: run_fork_tests("HomesteadToDaoAt5")

  @tag :ethereum_common_tests
  @tag :TangerineWhistle
  test "runs TangerineWhistle blockchain tests", do: run_fork_tests("TangerineWhistle")

  @tag :ethereum_common_tests
  @tag :SpuriousDragon
  test "runs SpuriousDragon blockchain tests", do: run_fork_tests("SpuriousDragon")

  @tag :ethereum_common_tests
  @tag :Byzantium
  test "runs Byzantium blockchain tests", do: run_fork_tests("Byzantium")

  @tag :ethereum_common_tests
  @tag :Constantinople
  test "runs Constantinople blockchain tests", do: run_fork_tests("Constantinople")

  @tag :ethereum_common_tests
  @tag :EIP158ToByzantiumAt5
  test "runs EIP158ToByzantiumAt5 blockchain tests", do: run_fork_tests("EIP158ToByzantiumAt5")

  @tag :ethereum_common_tests
  @tag :FrontierToHomesteadAt5
  test "runs FrontierToHomesteadAt5 blockchain tests",
    do: run_fork_tests("FrontierToHomesteadAt5")

  @tag :ethereum_common_tests
  @tag :HomesteadToEIP150At5
  test "runs HomesteadToEIP150At5 blockchain tests", do: run_fork_tests("HomesteadToEIP150At5")

  defp run_fork_tests(fork) do
    [{fork, all_tests()}]
    |> Task.async_stream(&run_tests(&1), timeout: @ten_minutes)
    |> Enum.flat_map(fn {:ok, results} -> results end)
    |> Enum.filter(&failing_test?/1)
    |> make_assertions()
  end

  defp failing_test?({:fail, _}), do: true
  defp failing_test?(_), do: false

  defp run_tests({fork, tests}) do
    tests
    |> Stream.reject(&known_fork_failures?(&1, fork))
    |> Enum.flat_map(fn json_test_path ->
      BlockchainTestRunner.run(json_test_path, fork)
    end)
  end

  defp known_fork_failures?(json_test_path, fork) do
    hardfork_failing_tests = Map.fetch!(@failing_tests, fork)

    Enum.any?(hardfork_failing_tests, fn failing_test ->
      String.contains?(json_test_path, failing_test)
    end)
  end

  defp forks_with_existing_implementation do
    @failing_tests
    |> Map.keys()
    |> Enum.reject(&fork_without_implementation?/1)
  end

  defp fork_without_implementation?(fork) do
    fork
    |> Chain.test_config()
    |> is_nil()
  end

  defp make_assertions([]), do: assert(true)
  defp make_assertions(failing_tests), do: refute(true, failure_message(failing_tests))

  defp failure_message(failing_tests) do
    total_failures = Enum.count(failing_tests)

    error_messages =
      failing_tests
      |> Enum.map(&single_error_message/1)
      |> Enum.join("\n")

    """
    Block hash mismatch for the following tests:
    #{error_messages}
    -----------------
    Total failures: #{inspect(total_failures)}
    """
  end

  defp single_error_message({:fail, {fork, test_name, expected, actual}}) do
    "[#{fork}] #{test_name}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  defp all_tests() do
    ethereum_common_tests_path()
    |> Path.join("/BlockchainTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
