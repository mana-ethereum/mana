defmodule EVM.Builtin do
  alias ExthCrypto.{Signature, Key}
  alias EVM.{Memory, Helpers}
  alias BN.IntegerModP.Point
  alias BN.IntegerModP
  alias BN.BN128Arithmetic

  @moduledoc """
  Implements the built-in functions as defined in Appendix E
  of the Yellow Paper. These are contract functions that
  natively exist in Ethereum.

  TODO: Implement and add doc tests.
  """
  @g_rip160_base 600
  @g_rip160_byte 120
  @g_sha256 60
  @g_256_byte 12
  @g_identity_base 15
  @g_identity_byte 3
  @g_ecrec 3000
  @g_quaddivisor 20
  @g_ec_add 500
  @g_ec_mult 40_000
  @g_ec_pairing_point 80_000
  @g_ec_pairing 100_000

  @data_size_limit 24_577

  @doc """
  A precompiled contract that recovers a public key from a signed hash
  (Elliptic curve digital signature algorithm public key recovery function)

  ## Examples

      iex> private_key = ExthCrypto.Test.private_key(:key_a)
      iex> {:ok, public_key} = ExthCrypto.Signature.get_public_key(private_key)
      iex> message = EVM.Helpers.left_pad_bytes("hello")
      iex> {signature, _r, _s, v} = ExthCrypto.Signature.sign_digest(message, private_key)
      iex> data = message <>  EVM.Helpers.left_pad_bytes(:binary.encode_unsigned(v + ExthCrypto.Signature.version())) <> EVM.Helpers.left_pad_bytes(signature)
      iex> {remaining_gas, _sub_state, _exec_env, result} = EVM.Builtin.run_ecrec(4000,  %EVM.ExecEnv{data: data})
      iex> remaining_gas
      1000
      iex> result == public_key
      ...>   |> ExthCrypto.Key.der_to_raw()
      ...>   |> EVM.Address.new_from_public_key()
      ...>   |> EVM.Helpers.left_pad_bytes()
      true
  """

  @spec run_ecrec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_ecrec(gas, exec_env = %EVM.ExecEnv{data: data}) do
    required_gas = @g_ecrec

    if required_gas <= gas do
      data = Memory.read_zeroed_memory(data, 0, 128)

      remaining_gas = gas - required_gas

      <<h::binary-size(32), v_with_version::binary-size(32), r::binary-size(32),
        s::binary-size(32)>> = data

      signature = r <> s
      v = :binary.decode_unsigned(v_with_version) - Signature.version()

      case Signature.recover(h, signature, v) do
        {:ok, public_key} ->
          padded_address =
            public_key
            |> Key.der_to_raw()
            |> EVM.Address.new_from_public_key()
            |> EVM.Helpers.left_pad_bytes()

          {remaining_gas, %EVM.SubState{}, exec_env, padded_address}

        {:error, _} ->
          {remaining_gas, %EVM.SubState{}, exec_env, :invalid_input}
      end
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @doc """
  Runs SHA256 hashing

  ## Examples

      iex> EVM.Builtin.run_sha256(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2928, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>}, <<3, 144, 88, 198,
        242, 192, 203, 73, 44, 83, 59, 10, 77, 20, 239,119, 204, 15, 120, 171, 204,
        206, 213, 40, 125, 132, 161, 162, 1, 28, 251, 129>>}
  """
  @spec run_sha256(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_sha256(gas, exec_env = %EVM.ExecEnv{data: data}) do
    required_gas = @g_sha256 + @g_256_byte * MathHelper.bits_to_words(byte_size(data))

    if required_gas <= gas do
      remaining_gas = gas - required_gas
      result = :crypto.hash(:sha256, data)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @doc """
  Runs RIPEMD160 hashing

  ## Examples

      iex> EVM.Builtin.run_rip160(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2280, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>},<<0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 121, 249, 1, 218, 38, 9, 240, 32, 173, 173, 191, 46, 95,
        104, 161, 108, 140, 63, 125, 87>>}
  """
  @spec run_rip160(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_rip160(gas, exec_env = %EVM.ExecEnv{data: data}) do
    required_gas = @g_rip160_base + @g_rip160_byte * MathHelper.bits_to_words(byte_size(data))

    if required_gas <= gas do
      remaining_gas = gas - required_gas
      result = :crypto.hash(:ripemd160, data) |> EVM.Helpers.left_pad_bytes(32)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @doc """
  Identity simply returnes the output as the input

  ## Examples

      iex> EVM.Builtin.run_id(3000,  %EVM.ExecEnv{data: <<1, 2, 3>>})
      {2982, %EVM.SubState{}, %EVM.ExecEnv{data: <<1, 2, 3>>},  <<1, 2, 3>>}
  """

  @spec run_id(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_id(gas, exec_env) do
    data = exec_env.data
    required_gas = @g_identity_base + @g_identity_byte * MathHelper.bits_to_words(byte_size(data))

    if required_gas <= gas do
      remaining_gas = gas - required_gas

      {remaining_gas, %EVM.SubState{}, exec_env, data}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @spec mod_exp(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def mod_exp(gas, exec_env) do
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

  @spec ec_add(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_add(gas, exec_env) do
    data = Memory.read_zeroed_memory(exec_env.data, 0, 128)

    <<x1_bin::binary-size(32), y1_bin::binary-size(32), x2_bin::binary-size(32),
      y2_bin::binary-size(32)>> = data

    x1 = :binary.decode_unsigned(x1_bin)
    y1 = :binary.decode_unsigned(y1_bin)
    x2 = :binary.decode_unsigned(x2_bin)
    y2 = :binary.decode_unsigned(y2_bin)

    cond do
      gas < @g_ec_add ->
        {0, %EVM.SubState{}, exec_env, :failed}

      x1 > IntegerModP.default_modulus() || x2 > IntegerModP.default_modulus() ||
        y1 > IntegerModP.default_modulus() || y2 > IntegerModP.default_modulus() ->
        {0, %EVM.SubState{}, exec_env, :failed}

      true ->
        calculate_ec_add({x1, y1}, {x2, y2}, gas, exec_env)
    end
  end

  @spec ec_mult(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_mult(gas, exec_env) do
    data = Memory.read_zeroed_memory(exec_env.data, 0, 96)

    <<x_bin::binary-size(32), y_bin::binary-size(32), scalar_bin::binary-size(32)>> = data

    x = :binary.decode_unsigned(x_bin)
    y = :binary.decode_unsigned(y_bin)
    scalar = :binary.decode_unsigned(scalar_bin)

    cond do
      gas < @g_ec_mult ->
        {0, %EVM.SubState{}, exec_env, :failed}

      x > IntegerModP.default_modulus() || y > IntegerModP.default_modulus() ->
        {0, %EVM.SubState{}, exec_env, :failed}

      true ->
        calculate_ec_mult({x, y}, scalar, gas, exec_env)
    end
  end

  @spec ec_pairing(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def ec_pairing(gas, exec_env) do
    data = exec_env.data
    pair_size = byte_size(exec_env.data)

    gas_cost = @g_ec_pairing_point * div(pair_size, 192) + @g_ec_pairing

    if rem(pair_size, 192) != 0 || gas < gas_cost do
      {0, %EVM.SubState{}, exec_env, :failed}
    else
      binary_pairs = for <<chunk::binary-size(192) <- data>>, do: <<chunk::binary-size(192)>>

      _pairs =
        Enum.map(binary_pairs, fn binary_pair ->
          <<x1::binary-size(32), y1::binary-size(32), x2_i::binary-size(32),
            x2_r::binary-size(32), y2_i::binary-size(32), y2_r::binary-size(32)>> = binary_pair

          {{x1, y1}, {x2_i, x2_r, y2_i, y2_r}}
        end)

      output = Helpers.left_pad_bytes(1, 32)
      gas_cost = @g_ec_pairing_point * div(pair_size, 192) + @g_ec_pairing

      {gas - gas_cost, %EVM.SubState{}, exec_env, output}
    end
  end

  @spec calculate_ec_add({integer, integer}, integer, EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  defp calculate_ec_mult({x, y}, scalar, gas, exec_env) do
    {:ok, point} = Point.new(x, y)

    if BN128Arithmetic.on_curve?(point) do
      {:ok, result} = BN128Arithmetic.mult(point, scalar)

      result_x = :binary.encode_unsigned(result.x.value)
      result_y = :binary.encode_unsigned(result.y.value)

      output = Helpers.left_pad_bytes(result_x, 32) <> Helpers.left_pad_bytes(result_y, 32)

      {gas - @g_ec_mult, %EVM.SubState{}, exec_env, output}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @spec calculate_ec_add({integer, integer}, {integer, integer}, EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  defp calculate_ec_add({x1, y1}, {x2, y2}, gas, exec_env) do
    {:ok, point1} = Point.new(x1, y1)
    {:ok, point2} = Point.new(x2, y2)

    if !BN128Arithmetic.on_curve?(point1) || !BN128Arithmetic.on_curve?(point2) do
      {0, %EVM.SubState{}, exec_env, :failed}
    else
      {:ok, result} = BN128Arithmetic.add(point1, point2)

      result_x = :binary.encode_unsigned(result.x.value)
      result_y = :binary.encode_unsigned(result.y.value)

      output = Helpers.left_pad_bytes(result_x, 32) <> Helpers.left_pad_bytes(result_y, 32)

      {gas - @g_ec_add, %EVM.SubState{}, exec_env, output}
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

  @spec e_length_prime(integer(), integer(), {integer(), binary()}) :: integer()
  defp e_length_prime(e_length, e, _) when e == 0 and e_length <= 32, do: 0

  defp e_length_prime(e_length, e, _) when e != 0 and e_length <= 32, do: highest_bit(e)

  defp e_length_prime(e_length, _e, {b_length, data}) do
    <<_::binary-size(b_length), e_first_32_bytes_bin::binary-size(32), _::binary>> = data

    e_first_32_bytes = :binary.decode_unsigned(e_first_32_bytes_bin)

    if e_first_32_bytes != 0 do
      8 * (e_length - 32) + highest_bit(e_first_32_bytes)
    else
      8 * (e_length - 32)
    end
  end

  @spec highest_bit(integer()) :: integer()
  defp highest_bit(number) do
    res =
      number
      |> :math.log2()
      |> MathHelper.floor()

    if res == 256, do: 255, else: res
  end
end
