defmodule EVM.Builtin.ModExp do
  alias EVM.Memory

  @data_size_limit 24_577
  @g_quaddivisor 20

  @doc """
  Arbitrary-precision exponentiation under modulo
  """
  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env) do
    lengths_size = 96
    length_data = Memory.read_zeroed_memory(exec_env.data, 0, lengths_size)

    <<base_length_bin::binary-size(32), exponent_length_bin::binary-size(32),
      modulus_length_bin::binary-size(32)>> = length_data

    base_length = :binary.decode_unsigned(base_length_bin)
    exponent_length = :binary.decode_unsigned(exponent_length_bin)
    modulus_length = :binary.decode_unsigned(modulus_length_bin)

    cond do
      base_length == 0 && modulus_length == 0 ->
        {gas, %EVM.SubState{}, exec_env, <<0>>}

      base_length <= @data_size_limit && exponent_length <= @data_size_limit &&
          modulus_length <= @data_size_limit ->
        calculate_mod_exp(base_length, exponent_length, modulus_length, exec_env, gas)

      true ->
        {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @spec calculate_mod_exp(integer(), integer(), integer(), EVM.ExecEnv.t(), EVM.Gas.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  defp calculate_mod_exp(base_length, exponent_length, modulus_length, exec_env, gas) do
    lengths_size = 96

    data =
      Memory.read_zeroed_memory(
        exec_env.data,
        lengths_size,
        base_length + exponent_length + modulus_length
      )

    <<base_bin::binary-size(base_length), exponent_bin::binary-size(exponent_length),
      modulus_bin::binary-size(modulus_length)>> = data

    base = :binary.decode_unsigned(base_bin)
    exponent = :binary.decode_unsigned(exponent_bin)
    modulus = :binary.decode_unsigned(modulus_bin)

    required_gas =
      MathHelper.floor(
        f(max(base_length, modulus_length)) *
          max(e_length_prime(exponent_length, exponent, {base_length, data}), 1) / @g_quaddivisor
      )

    if required_gas <= gas do
      result =
        cond do
          modulus_length == 0 -> <<>>
          modulus <= 1 -> <<0>>
          exponent == 0 -> <<1>>
          base == 0 -> <<0>>
          true -> :crypto.mod_pow(base, exponent, modulus)
        end
        |> EVM.Helpers.left_pad_bytes(modulus_length)

      remaining_gas = gas - required_gas

      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @spec f(integer()) :: integer()
  defp f(x) when x <= 64, do: x * x

  defp f(x) when x > 64 and x <= 1024 do
    MathHelper.floor(x * x / 4) + 96 * x - 3_072
  end

  defp f(x) do
    MathHelper.floor(x * x / 16) + 480 * x - 199_680
  end

  @spec e_length_prime(non_neg_integer(), non_neg_integer(), {non_neg_integer(), binary()}) ::
          integer()
  defp e_length_prime(e_length, e, _) when e == 0 and e_length <= 32, do: 0

  defp e_length_prime(e_length, e, _) when e_length < 32 do
    e_bin = :binary.encode_unsigned(e)
    8 * (e_length - 32) + highest_bit(e_bin, e_length)
  end

  defp e_length_prime(e_length, e, _) when e_length == 32 do
    e_bin =
      e
      |> :binary.encode_unsigned()
      |> EVM.Helpers.left_pad_bytes()

    8 * (e_length - 32) + highest_bit(e_bin, e_length)
  end

  defp e_length_prime(e_length, _e, {b_length, data}) do
    <<_::binary-size(b_length), e_first_32_bytes_bin::binary-size(32), _::binary>> = data

    e_first_32_bytes = :binary.decode_unsigned(e_first_32_bytes_bin)

    if e_first_32_bytes == 0 do
      8 * (e_length - 32)
    else
      8 * (e_length - 32) + highest_bit(e_first_32_bytes_bin, e_length)
    end
  end

  @spec highest_bit(binary(), non_neg_integer()) :: non_neg_integer()
  defp highest_bit(_, 0), do: 0

  defp highest_bit(binary_number, _) do
    bit_list = for <<b::1 <- binary_number>>, do: b

    if List.first(bit_list) == 1 do
      255
    else
      index = Enum.find_index(bit_list, fn x -> x != 0 end)

      index = index || 0

      255 - index
    end
  end
end
