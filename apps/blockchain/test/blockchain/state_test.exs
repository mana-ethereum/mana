defmodule Blockchain.StateTest do
  alias Blockchain.Account
  alias MerklePatriciaTree.Trie
  alias EthCommonTest.{Helpers, StateTestRunner}

  use EthCommonTest.Harness
  use ExUnit.Case, async: true

  @failing_tests %{
    "Byzantium" => [
      "stReturnDataTest/modexp_modsize0_returndatasize",
      "stReturnDataTest/returndatacopy_after_revert_in_staticcall",
      "stReturnDataTest/returndatacopy_after_successful_callcode",
      "stReturnDataTest/returndatacopy_after_successful_delegatecall",
      "stReturnDataTest/returndatacopy_after_successful_staticcall",
      "stReturnDataTest/returndatacopy_following_call",
      "stReturnDataTest/returndatacopy_following_revert",
      "stRevertTest/RevertInCallCode",
      "stRevertTest/RevertInCreateInInit",
      "stRevertTest/RevertInDelegateCall"
    ],
    "Constantinople" => [
      "stCreate2/CREATE2_ContractSuicideDuringInit_ThenStoreThenReturn",
      "stCreate2/CREATE2_Suicide",
      "stCreate2/Create2OOGafterInitCode",
      "stCreate2/Create2OOGafterInitCodeReturndata2",
      "stCreate2/Create2OOGafterInitCodeRevert",
      "stCreate2/Create2OnDepth1023",
      "stCreate2/Create2OnDepth1024",
      "stCreate2/Create2Recursive",
      "stCreate2/CreateMessageReverted",
      "stCreate2/CreateMessageRevertedOOGInInit",
      "stCreate2/RevertDepthCreate2OOG",
      "stCreate2/RevertDepthCreateAddressCollision",
      "stCreate2/RevertInCreateInInit",
      "stCreate2/RevertOpcodeCreate",
      "stCreate2/RevertOpcodeInCreateReturns",
      "stCreate2/call_outsize_then_create2_successful_then_returndatasize",
      "stCreate2/call_then_create2_successful_then_returndatasize",
      "stCreate2/create2InitCodes",
      "stCreate2/create2SmartInitCode",
      "stCreate2/create2callPrecompiles",
      "stCreate2/create2checkFieldsInInitcode",
      "stCreate2/create2collisionBalance",
      "stCreate2/create2collisionSelfdestructed",
      "stCreate2/create2collisionStorage",
      "stCreate2/returndatacopy_0_0_following_successful_create",
      "stCreate2/returndatacopy_afterFailing_create",
      "stCreate2/returndatacopy_following_revert_in_create",
      "stCreate2/returndatasize_following_successful_create"
    ],
    "Frontier" => [],
    "Homestead" => [],
    "SpuriousDragon" => [],
    "TangerineWhistle" => []
  }

  @fifteen_minutes 1000 * 60 * 15
  @num_test_groups 10

  @tag :ethereum_common_tests
  @tag :state_common_tests
  test "Blockchain state tests" do
    grouped_test_per_fork()
    |> Task.async_stream(&run_tests(&1), timeout: @fifteen_minutes)
    |> Enum.flat_map(fn {:ok, results} -> results end)
    |> make_assertions()
  end

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
    |> Stream.reject(&known_fork_failure?(&1, fork))
    |> Enum.flat_map(&StateTestRunner.run(&1, fork))
    |> Enum.filter(&failed_test?/1)
  end

  defp forks_with_existing_implementation do
    @failing_tests
    |> Map.keys()
    |> Enum.reject(&fork_without_implementation?/1)
  end

  defp fork_without_implementation?(fork) do
    fork
    |> Helpers.human_readable_fork_name()
    |> EVM.Configuration.hardfork_config()
    |> is_nil()
  end

  defp known_fork_failure?(json_test_path, hardfork) do
    test_name = test_name_with_group_from_path(json_test_path)
    failing_tests = Map.fetch!(@failing_tests, hardfork)

    Enum.member?(failing_tests, test_name)
  end

  defp test_name_with_group_from_path(path) do
    path_elements =
      path
      |> Path.rootname()
      |> Path.split()

    group_name = Enum.fetch!(path_elements, -2)
    test_name = Enum.fetch!(path_elements, -1)

    Path.join(group_name, test_name)
  end

  defp failed_test?(%{state_root_mismatch: true}), do: true
  defp failed_test?(%{logs_hash_mismatch: true}), do: true
  defp failed_test?(%{}), do: false

  defp make_assertions([]), do: assert(true)
  defp make_assertions(failing_tests), do: assert(false, failure_message(failing_tests))

  defp failure_message(failing_tests) do
    """
    #{state_root_failures_message(failing_tests)}
    =========================

    #{logs_hash_error_message(failing_tests)}
    """
  end

  defp state_root_failures_message(failing_tests) do
    state_root_mismatch_failures =
      Enum.filter(failing_tests, fn test -> test.state_root_mismatch end)

    total_count = Enum.count(state_root_mismatch_failures)

    state_root_error_messages =
      state_root_mismatch_failures
      |> Enum.map(&single_state_root_error_message/1)
      |> Enum.join("\n")

    """
    State root mismatch for the following tests:
    #{state_root_error_messages}
    -----------------
    Total state root failures: #{inspect(total_count)}
    """
  end

  defp logs_hash_error_message(failing_tests) do
    logs_hash_mismatch_failures =
      Enum.filter(failing_tests, fn test -> test.logs_hash_mismatch end)

    total_count = Enum.count(logs_hash_mismatch_failures)

    logs_hash_error_messages =
      logs_hash_mismatch_failures
      |> Enum.map(&single_logs_hash_error_message/1)
      |> Enum.join("\n")

    """
    Logs hash mismatch for the following tests:
    #{inspect(logs_hash_error_messages)}
    -----------------
    Total logs hash failures: #{inspect(total_count)}
    """
  end

  defp single_logs_hash_error_message(test_result) do
    %{
      hardfork: hardfork,
      test_source: test_source,
      logs_hash_expected: expected,
      logs_hash_actual: actual
    } = test_result

    "[#{hardfork}] #{test_source}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  defp single_state_root_error_message(test_result) do
    %{
      hardfork: hardfork,
      test_source: test_source,
      state_root_expected: expected,
      state_root_actual: actual
    } = test_result

    "[#{hardfork}] #{test_source}: expected #{inspect(expected)}, but received #{inspect(actual)}"
  end

  def dump_state(state) do
    state
    |> Trie.Inspector.all_values()
    |> Enum.map(fn {key, value} ->
      k = Base.encode16(key, case: :lower)
      v = value |> ExRLP.decode() |> Account.deserialize()
      {k, v}
    end)
    |> Enum.map(fn {address_key, account} ->
      IO.puts(address_key)
      IO.puts("  Balance: #{account.balance}")
      IO.puts("  Nonce: #{account.nonce}")
      IO.puts("  Storage Root:")
      IO.puts("  " <> Base.encode16(account.storage_root))
      IO.puts("  Code Hash")
      IO.puts("  " <> Base.encode16(account.code_hash))
    end)
  end

  defp tests do
    ethereum_common_tests_path()
    |> Path.join("/GeneralStateTests/**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end
end
