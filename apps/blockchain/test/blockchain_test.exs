defmodule BlockchainTest do
  use ExUnit.Case

  import EthCommonTest.Helpers

  alias Blockchain.Chain
  alias EthCommonTest.BlockchainTestRunner

  doctest Blockchain

  @failing_byzantium_tests File.read!(System.cwd() <> "/test/support/byzantium_failing_tests.txt")
  @failing_constantinople_tests File.read!(
                                  System.cwd() <> "/test/support/constantinople_failing_tests.txt"
                                )

  @failing_tests %{
    "Frontier" => [],
    "Homestead" => [],
    "TangerineWhistle" => [],
    "SpuriousDragon" => [],
    "Byzantium" => String.split(@failing_byzantium_tests, "\n"),
    "Constantinople" => String.split(@failing_constantinople_tests, "\n"),
    # the rest are not implemented yet
    "EIP158ToByzantiumAt5" => [],
    "FrontierToHomesteadAt5" => [],
    "HomesteadToDaoAt5" => [],
    "HomesteadToEIP150At5" => []
  }

  @ten_minutes 1000 * 60 * 10
  @num_test_groups 10

  @tag :ethereum_common_tests
  @tag :blockchain_common_tests
  test "runs blockchain tests" do
    grouped_test_per_fork()
    |> Task.async_stream(&run_tests(&1), timeout: @ten_minutes)
    |> Enum.flat_map(fn {:ok, results} -> results end)
    |> Enum.filter(&failing_test?/1)
    |> make_assertions()
  end

  defp failing_test?({:fail, _}), do: true
  defp failing_test?(_), do: false

  defp grouped_test_per_fork do
    for fork <- forks_with_existing_implementation(),
        test_group <- split_tests_into_groups(@num_test_groups),
        do: {fork, test_group}
  end

  defp split_tests_into_groups(num_groups_desired) do
    all_tests = tests()
    test_count = Enum.count(all_tests)
    tests_per_group = div(test_count, num_groups_desired)

    Enum.chunk_every(all_tests, tests_per_group)
  end

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

  defp tests do
    ethereum_common_tests_path()
    |> Path.join("/BlockchainTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
