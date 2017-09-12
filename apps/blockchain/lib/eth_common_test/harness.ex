defmodule EthCommonTest.Harness do
  @moduledoc """
  Harness for running tests off of the Ethereum Common Test suite.
  """

  defmacro __using__(opts) do
    quote do
      import EthCommonTest.Helpers
      import EthCommonTest.Harness, only: [eth_test: 4]
    end
  end

  defmacro eth_test(test_set, test_subset, tests, fun) do
    for {test_name, test} <- EthCommonTest.Helpers.read_test_file(test_set, test_subset),
      ( tests == :all or Enum.member?(tests, String.to_atom(test_name)) ) do
        json = Poison.encode!(test)

        quote do
          test("#{unquote(test_set)} - #{unquote(test_subset)} - #{unquote(test_name)}") do
            test = unquote(json) |> Poison.decode!
            unquote(fun).(test, unquote(test_name))
          end
        end
    end
  end

end