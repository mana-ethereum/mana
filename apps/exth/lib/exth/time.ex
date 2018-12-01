defmodule Exth.Time do
  @type time :: Time.t()

  @unit_abbreviations %{
    second: "s",
    millisecond: "ms",
    microsecond: "µs",
    nanosecond: "ns",
    seconds: "s",
    milliseconds: "ms",
    microseconds: "µs",
    nanoseconds: "ns"
  }

  @spec time_start() :: time()
  def time_start() do
    Time.utc_now()
  end

  @spec elapsed(fun() | time(), System.time_unit()) :: String.t()
  def elapsed(start_or_fun, unit \\ :millisecond)

  def elapsed(fun, unit) when is_function(fun) do
    start = time_start()
    fun.()
    elapsed(start, unit)
  end

  def elapsed(start, unit) do
    total_time = Time.diff(Time.utc_now(), start, unit)

    "#{total_time}#{get_unit_abbreviation(unit)}"
  end

  @spec rate(non_neg_integer(), time(), String.t(), System.time_unit()) :: String.t()
  def rate(count, start, desc, unit) do
    total_time = Time.diff(Time.utc_now(), start, unit)

    if total_time == 0 do
      "n/a"
    else
      total_rate = count / total_time

      "#{total_rate} #{desc}/#{get_unit_abbreviation(unit)}"
    end
  end

  @spec get_unit_abbreviation(System.time_unit()) :: String.t() | no_return()
  defp get_unit_abbreviation(unit) do
    Map.fetch!(@unit_abbreviations, unit)
  end
end
