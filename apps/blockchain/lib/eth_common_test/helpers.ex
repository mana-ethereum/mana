defmodule EthCommonTest.Helpers do
  @moduledoc """
  Helper functions that will be generally available to test cases
  when they use `EthCommonTest`.
  """
  require Integer
  require Logger

  @type test_case :: %{}

  @ten_minutes 1000 * 60 * 10

  @spec load_integer(String.t()) :: integer() | nil
  def load_integer(""), do: 0
  def load_integer("x" <> data), do: maybe_hex(data, :integer)
  def load_integer("0x" <> data), do: maybe_hex(data, :integer)
  def load_integer(data), do: maybe_dec(data)

  @spec maybe_address(String.t() | nil) :: binary() | nil
  def maybe_address(hex_data), do: maybe_hex(hex_data)

  @spec maybe_hex(String.t() | nil) :: binary() | nil
  def maybe_hex(hex_data, type \\ :raw)
  def maybe_hex(nil, _), do: nil
  def maybe_hex(hex_data, :raw), do: load_raw_hex(hex_data)
  def maybe_hex(hex_data, :integer), do: load_hex(hex_data)

  @spec maybe_dec(String.t() | nil) :: integer() | nil
  def maybe_dec(nil), do: nil
  def maybe_dec(els), do: load_decimal(els)

  @spec load_decimal(String.t()) :: integer()
  def load_decimal(dec_data) do
    {res, ""} = Integer.parse(dec_data)

    res
  end

  @spec load_raw_hex(String.t()) :: binary()
  def load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)

  def load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: load_raw_hex("0" <> hex_data)

  def load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end

  @spec load_hex(String.t()) :: integer()
  def load_hex(hex_data), do: hex_data |> load_raw_hex |> :binary.decode_unsigned()

  @spec read_test_file(String.t()) :: any()
  def read_test_file(file_name) do
    # This is pretty terrible, but the JSON is just messed up in a number
    # of these tests (it contains duplicate keys with very strange values)
    body =
      file_name
      |> File.read!()
      |> String.split("\n")
      |> Enum.filter(fn x -> not (x |> String.contains?("secretkey ")) end)
      |> Enum.join("\n")

    Poison.decode!(body)
  end

  @spec test_file_name(String.t(), String.t()) :: String.t()
  def test_file_name(test_set, test_subset) do
    Path.join(ethereum_common_tests_path(), "#{test_set}/#{to_string(test_subset)}.json")
  end

  @spec test_files(String.t(), keyword(String.t())) :: [String.t()]
  def test_files(test_set, options \\ []) do
    tests_to_ignore = Keyword.get(options, :ignore, [])

    tests =
      ethereum_common_tests_path()
      |> Path.join("#{test_set}/**/*.json")
      |> Path.wildcard()

    Enum.reject(tests, fn test_path ->
      Enum.any?(tests_to_ignore, &String.contains?(test_path, &1))
    end)
  end

  @spec load_src(String.t(), String.t()) :: any()
  def load_src(filler_type, filler) do
    "src/#{filler_type}" |> test_file_name(filler) |> read_test_file()
  end

  @doc """
  The Ethereum common tests use EIP numbers to refer to forks in some cases.

  Once [this issue](https://github.com/ethereum/tests/issues/488) is closed we can remove this helper.
  """

  def human_readable_fork_name(fork) do
    case fork do
      "EIP150" -> "TangerineWhistle"
      "EIP158" -> "SpuriousDragon"
      fork -> fork
    end
  end

  def test_suite_fork_name(fork) do
    case fork do
      "TangerineWhistle" -> "EIP150"
      "SpuriousDragon" -> "EIP158"
      fork -> fork
    end
  end

  @spec ethereum_common_tests_path :: String.t()
  def ethereum_common_tests_path do
    Path.join(System.cwd(), "/../../ethereum_common_tests")
  end

  @spec known_failures_path :: String.t()
  def known_failures_path do
    Path.join(System.cwd(), "/test/support/known_failures.txt")
  end

  @spec run_common_tests(
          String.t(),
          (String.t() -> no_return()),
          (String.t(), test_case() -> no_return())
        ) :: no_return()
  def run_common_tests(test_set_name, fail_fun, runner) do
    # `common_test_files` are simply a list of paths to tests for test_set_name
    # these are top-level folder names in `ethereum_common_tests`
    common_test_files = test_files(test_set_name)
    known_failures = load_known_failures_or_blank()
    {test_cases, skips} = read_test_cases(test_set_name, common_test_files, known_failures)

    {:ok, task_sup} = Task.Supervisor.start_link()

    # Start a task for each test.
    tasks =
      Task.Supervisor.async_stream_nolink(
        task_sup,
        test_cases,
        fn {test_name, test_case} ->
          runner.(test_name, test_case)

          test_name
        end,
        timeout: @ten_minutes
      )

    {successes, failures} = group_tasks(tasks)

    success_count = Enum.count(successes)
    failure_count = Enum.count(failures)
    skip_count = Enum.count(skips)

    result_message =
      "#{test_set_name}: #{success_count} success(es), #{skip_count} skip(s), #{failure_count} failure(s)"

    if failure_count > 0 do
      # If we have any failures, fail
      fail_fun.(result_message)
    else
      Logger.warn(result_message)
    end
  end

  # Returns a list of known failures (as regexs) or an empty list if
  # known_failures.txt does not exist for this app
  @spec load_known_failures_or_blank() :: [Regex.t()]
  defp load_known_failures_or_blank() do
    case File.read(known_failures_path()) do
      {:ok, data} ->
        data
        |> String.split("\n")
        |> Enum.filter(fn l -> !Regex.match?(~r/^\s*$/, l) end)
        |> Enum.map(&Regex.compile!/1)

      _ ->
        []
    end
  end

  # Reads test cases from `ethereum_common_tests` based on the file paths
  # given. Compares each test against `known_failures` and returns skipped
  # tests as a separate list.
  @spec read_test_cases(String.t(), [String.t()], [Regex.t()]) :: {[test_case()], [test_case()]}
  defp read_test_cases(test_set_name, common_test_files, known_failures) do
    # `all_test_cases` is the set of test cases, including the ones we plan to
    # skip since they are known failures
    all_test_cases =
      for test_path <- common_test_files do
        # `test_data` is a map of test-name to test-cases that comes from json file
        # `#{ethereum_common_tests}/#{test_name}/#{test_path}`.

        # These tests are arbitrary JSON that's specific to what's being tested
        # Thus, we simply call `fun.()` with the name of the test and that
        # decoded json object.

        # `test_data` is the decoded json from the test.
        test_data = EthCommonTest.Helpers.read_test_file(test_path)

        for {test_name, test_case} <- test_data do
          full_name = "#{test_set_name}/#{test_path}/#{test_name}"
          skip = Enum.any?(known_failures, fn r -> Regex.match?(r, full_name) end)

          {{test_name, test_case}, skip}
        end
      end

    Enum.reduce(List.flatten(all_test_cases), {[], []}, fn
      {t, false}, {tests, skips} ->
        {[t | tests], skips}

      {t, true}, {tests, skips} ->
        {tests, [t | skips]}
    end)
  end

  # Groups the results of tasks together into successes or failures
  @spec group_tasks(Enumerable.t()) :: {[String.t()], [any()]}
  defp group_tasks(tasks) do
    # Then gather up the successes and failures
    # Note: we currently have the exits for the failure
    #       but the exit doesn't include the test name
    Enum.reduce(tasks, {[], []}, fn
      {:ok, test_name}, {succ, fail} ->
        {[test_name | succ], fail}

      {:exit, error}, {succ, fail} ->
        {succ, [error | fail]}
    end)
  end
end
