defmodule EthCommonTest.Helpers do
  @moduledoc """
  Helper functions that will be generally available to test cases
  when they use `EthCommonTest`.
  """

  require Integer

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

  @spec ethereum_common_tests_path :: String.t()
  def ethereum_common_tests_path do
    Path.join(System.cwd(), "/../../ethereum_common_tests")
  end
end
