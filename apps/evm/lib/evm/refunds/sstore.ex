defmodule EVM.Refunds.Sstore do
  alias EVM.{ExecEnv, Configuration}

  # Refund given (added into refund counter) when the storage value is set to zero from non-zero.
  @storage_refund 15_000

  @spec refund({integer(), integer()}, ExecEnv.t()) :: integer()
  def refund({key, new_value}, exec_env) do
    if Configuration.eip1283_sstore_gas_cost_changed?(exec_env.config) do
      eip1283_sstore_refund({key, new_value}, exec_env)
    else
      basic_sstore_refund({key, new_value}, exec_env)
    end
  end

  defp basic_sstore_refund({key, new_value}, exec_env) do
    case ExecEnv.get_storage(exec_env, key) do
      {:ok, value} ->
        if value != 0 && new_value == 0 do
          @storage_refund
        else
          0
        end

      _ ->
        0
    end
  end

  # credo:disable-for-next-line
  defp eip1283_sstore_refund({key, new_value}, exec_env) do
    initial_value = get_initial_value(exec_env, key)
    current_value = get_current_value(exec_env, key)

    cond do
      current_value == new_value ->
        0

      initial_value == current_value && initial_value == 0 ->
        0

      initial_value == current_value && new_value == 0 ->
        15_000

      true ->
        first_refund =
          cond do
            initial_value != 0 && current_value == 0 ->
              -15_000

            initial_value != 0 && new_value == 0 ->
              15_000

            true ->
              0
          end

        second_refund =
          cond do
            initial_value == new_value && initial_value == 0 ->
              19_800

            initial_value == new_value ->
              4_800

            true ->
              0
          end

        first_refund + second_refund
    end
  end

  defp get_initial_value(exec_env, key) do
    case ExecEnv.get_initial_storage(exec_env, key) do
      :account_not_found -> 0
      :key_not_found -> 0
      {:ok, value} -> value
    end
  end

  defp get_current_value(exec_env, key) do
    case ExecEnv.get_storage(exec_env, key) do
      :account_not_found -> 0
      :key_not_found -> 0
      {:ok, value} -> value
    end
  end
end
