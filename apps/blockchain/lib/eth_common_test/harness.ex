defmodule EthCommonTest.Harness do
  @moduledoc """
  Harness for running tests off of the Ethereum Common Test suite.
  """

  defmacro __using__(_opts) do
    quote do
      import EthCommonTest.Helpers
      import EthCommonTest.Harness, only: [define_common_tests: 3]
    end
  end

  defmacro define_common_tests(test_set, options, fun) do
    common_tests = EthCommonTest.Helpers.test_files(test_set, options)

    for test_path <- common_tests do
      test_data = EthCommonTest.Helpers.read_test_file(test_path)
      test_name = Path.basename(test_path, ".json")

      json_data = Poison.encode!(test_data)

      quote do
        test("#{unquote(test_name)}") do
          data = unquote(json_data) |> Poison.decode!()

          unquote(fun).(unquote(test_name), data)
        end
      end
    end
  end
end
