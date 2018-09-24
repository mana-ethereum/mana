defmodule Mix.Tasks.CommonTests.Run do
  use Mix.Task

  require Logger

  @shortdoc "Runs a single blockchain common test"

  @moduledoc """
  Runs a single blockchain common test.

  Note that this must be run with `MIX_ENV=test`.

  ## Example

  From the blockchain app,

  ```
  MIX_ENV=test mix common_tests.run "stSpecialTest/failed_tx" --fork "EIP158"
  ```

  ## Command line options

  * `--fork` - the name of the hardfork to run (optional)
  """

  @preferred_cli_env :test
  @switches [test: :string, fork: :string]
  @aliases [hardfork: :fork]

  def run(args) do
    {opts, [test_name | _]} = OptionParser.parse!(args, switches: @switches, aliases: @aliases)
    hardfork = Keyword.get(opts, :fork, :all)

    test_name
    |> find_full_name()
    |> BlockchainTestRunner.run(hardfork)
    |> Enum.map(&log_result/1)
  end

  defp log_result({:pass, {fork, name, _ex, _act}}) do
    Mix.shell().info("[#{fork}] #{name} passed")
  end

  defp log_result({:fail, {fork, name, expected, actual}}) do
    message = """

    [#{fork}] #{name} failed:

      Expected: #{Base.encode16(expected, case: :lower)},
      Actual: #{Base.encode16(actual, case: :lower)}
    """

    Mix.shell().error(message)
  end

  defp find_full_name(name) do
    EthCommonTest.Helpers.ethereum_common_tests_path()
    |> Path.join("/BlockchainTests/**/*.json")
    |> Path.wildcard()
    |> Enum.find(fn full_name ->
      String.contains?(full_name, name)
    end)
  end
end
