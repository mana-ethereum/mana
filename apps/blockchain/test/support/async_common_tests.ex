defmodule Blockchain.AsyncCommonTests do
  @moduledoc """
  Module to help spawn a process for each ethereum fork when testing Ethereum
  Common Tests
  """

  @ten_minutes 1000 * 60 * 10

  @doc """
  Spawns a process for given `fork` and calls the function provided to get
  results.

  Returns a three tuple, `{fork_name, fork_process_pid, fork_ref}` to be
  used with `receive_replies/1`.
  """
  def spawn_forks(forks, run_fork_test_fn) do
    Enum.map(forks, fn fork ->
      {fork_pid, fork_ref} = spawn_tests_for_fork(fork, run_fork_test_fn)
      {fork, fork_pid, fork_ref}
    end)
  end

  @doc """
  Expects list of three tuples returned from `spawn_forks/2` and waits for
  messages from spawned processes.

  This will return an aggregated list of the results returned by the function
  provided to `spawn_forks/2`, or it will raise an error if one of the fork
  processes crashes or takes too long.
  """
  def receive_replies(replies, timeout \\ @ten_minutes) when is_list(replies) do
    Enum.flat_map(replies, &receive_reply(&1, timeout))
  end

  defp receive_reply({fork, fork_pid, fork_ref}, timeout) do
    case receive_fork_reply(fork_pid, fork_ref, timeout) do
      {:fork_failure, error} ->
        raise fork_failure_error(fork, error)

      {:fork_timeout, stacktrace} ->
        raise fork_timeout_error(fork, stacktrace, timeout)

      results ->
        results
    end
  end

  defp fork_failure_error(fork, error) do
    "[#{fork}] error: #{inspect(error)}"
  end

  defp fork_timeout_error(fork, stacktrace, timeout) do
    "[#{fork}] timeout after #{inspect(timeout)} milliseconds: #{inspect(stacktrace)}"
  end

  defp spawn_tests_for_fork(fork, run_fork_test_fn) do
    parent = self()

    spawn_monitor(fn ->
      results = run_fork_test_fn.(fork)
      send(parent, {self(), :fork_tests_finished, results})
      exit(:shutdown)
    end)
  end

  defp receive_fork_reply(fork_pid, fork_ref, timeout) do
    receive do
      {^fork_pid, :fork_tests_finished, results} ->
        Process.demonitor(fork_ref, [:flush])
        results

      {:DOWN, ^fork_ref, :process, ^fork_pid, error} ->
        {:fork_failure, error}
    after
      timeout ->
        case Process.info(fork_pid, :current_stacktrace) do
          {:current_stacktrace, stacktrace} ->
            Process.demonitor(fork_ref, [:flush])
            Process.exit(fork_pid, :kill)
            {:fork_timeout, stacktrace}

          nil ->
            receive_fork_reply(fork_pid, fork_ref, timeout)
        end
    end
  end
end
