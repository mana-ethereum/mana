defmodule EthCommonTest.Helpers do
  @moduledoc """
  Helper functions that will be generally available to test cases
  when they use `EthCommonTest`.
  """

  require Integer

  @spec maybe_hex(String.t | nil) :: binary() | nil
  def maybe_address(hex_data), do: maybe_hex(hex_data)

  @spec maybe_hex(String.t | nil) :: binary() | nil
  def maybe_hex(hex_data, type \\ :raw)
  def maybe_hex(nil, _), do: nil
  def maybe_hex(hex_data, :raw), do: load_raw_hex(hex_data)
  def maybe_hex(hex_data, :integer), do: load_hex(hex_data)

  def maybe_dec(nil), do: nil
  def maybe_dec(els), do: load_decimal(els)

  def load_decimal(dec_data) do
    {res, ""} = Integer.parse(dec_data)

    res
  end

  @spec load_raw_hex(String.t) :: binary()
  def load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)
  def load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)), do: load_raw_hex("0" <> hex_data)
  def load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end

  @spec load_hex(String.t) :: integer()
  def load_hex(hex_data), do: hex_data |> load_raw_hex |> :binary.decode_unsigned

  @spec read_test_file(atom(), atom()) :: any()
  def read_test_file(test_set, test_subset) do
    {:ok, body} = File.read(test_file_name(test_set, test_subset))

    Poison.decode!(body)
  end

  @spec test_file_name(atom(), atom()) :: String.t
  def test_file_name(test_set, test_subset) do
    "test/support/ethereum_common_tests/#{test_set}/#{to_string(test_subset)}.json"
  end

  @spec load_src(String.t, String.t, String.t) :: any()
  def load_src(filler_type, filler, sub_set) do
    read_test_file("src/#{filler_type}", filler)[sub_set]
  end

end