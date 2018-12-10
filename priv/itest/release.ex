defmodule Release do
  @moduledoc """
  Finds the release tarball, extracts, and applies all tests.
  """
  def main(_) do
    # a list of test modules (We could discover them by test postfix in module name)
    tests = [
      WebsocketTest.tests()
    ]

    untar_and_start()
    |> find_and_extract_release()
    |> do_test(tests)
  end

  defp untar_and_start() do
    dir = Path.join(System.cwd(), "/../../")
    path = recursive_search(dir, "mana.tar.gz")
    path
  end

  defp find_and_extract_release(path) do
    untar_path = '/tmp/mana/'
    :ok = :erl_tar.extract(String.to_charlist(path), [{:cwd, untar_path}, :compressed])
    recursive_search(untar_path, "mana")
  end

  defp do_test(_, []), do: :ok

  defp do_test(start_path, [h | t]) do
    [start_flags, tests] = h
    GenServer.start(Starter, [start_path, start_flags.()])
    Enum.each(tests, fn test -> test.() end)
    GenServer.stop(Starter)
    do_test(start_path, t)
  end

  defp recursive_search(dir, find_file) do
    try do
      do_recursive_search(dir, find_file)
    catch
      :throw, payload ->
        payload
    end
  end

  defp do_recursive_search(dir, find_file) do
    Enum.find(
      File.ls!(dir),
      fn
        ^find_file ->
          throw(Path.join([dir, find_file]))

        file ->
          fname = "#{dir}/#{file}"
          if File.dir?(fname), do: do_recursive_search(fname, find_file)
      end
    )
  end
end
