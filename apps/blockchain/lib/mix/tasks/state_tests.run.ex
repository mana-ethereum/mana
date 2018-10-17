defmodule Mix.Tasks.StateTests.Run do
  use Mix.Task

  require Logger

  alias EthCommonTest.StateTestRunner

  @shortdoc "Runs a single state common test"

  @moduledoc """
  Runs a single state common test.

  ## Example

  From the blockchain app,

  ```
  mix state_tests.run "stRevertTest/RevertInCallCode" --fork "Byzantium"
  ```

  ## Command line options

  * `--fork`, `-f` - the name of the hardfork to run (optional)
  """

  @preferred_cli_env :test
  @switches [test: :string, fork: :string]
  @aliases [f: :fork]

  def run(args) do
    {opts, [test_name | _]} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)

    hardfork = Keyword.get(opts, :fork, :all)

    test_name
    |> find_full_name()
    |> StateTestRunner.run(hardfork)
    |> Enum.map(&log_result/1)
  end

  defp log_result(result = %{state_root_mismatch: true}) do
    message = """

    [#{result.hardfork}] #{result.test_name} state root mismatch:

      Expected: #{encode(result.state_root_expected)},
      Actual: #{encode(result.state_root_actual)}
    """

    Mix.shell().error(message)
  end

  defp log_result(result = %{logs_hash_mismatch: true}) do
    message = """

    [#{result.hardfork}] #{result.test_name} logs hash mismatch:

      Expected: #{encode(result.logs_hash_expected)},
      Actual: #{encode(result.logs_hash_actual)}
    """

    Mix.shell().error(message)
  end

  defp log_result(%{hardfork: fork, test_name: name}) do
    Mix.shell().info("[#{fork}] #{name} passed")
  end

  def encode(value) do
    Base.encode16(value, case: :lower)
  end

  defp find_full_name(name) do
    EthCommonTest.Helpers.ethereum_common_tests_path()
    |> Path.join("/GeneralStateTests/**/*.json")
    |> Path.wildcard()
    |> Enum.find(fn full_name ->
      String.contains?(full_name, name)
    end)
  end
end
