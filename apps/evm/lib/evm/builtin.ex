defmodule EVM.Builtin do
  alias ExthCrypto.{Signature, Key}
  alias EVM.{Helpers, Memory}

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
    used_gas = @g_ecrec

    if used_gas <= gas do
      data =
        data
        |> Helpers.right_pad_bytes(128)
        |> :binary.bin_to_list()
        |> Enum.take(128)
        |> :binary.list_to_bin()

      remaining_gas = gas - used_gas

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
    used_gas = @g_sha256 + @g_256_byte * MathHelper.bits_to_words(byte_size(data))

    if used_gas <= gas do
      remaining_gas = gas - used_gas
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
    used_gas = @g_rip160_base + @g_rip160_byte * MathHelper.bits_to_words(byte_size(data))

    if used_gas <= gas do
      remaining_gas = gas - used_gas
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
    used_gas = @g_identity_base + @g_identity_byte * MathHelper.bits_to_words(byte_size(data))

    if used_gas <= gas do
      remaining_gas = gas - used_gas

      {remaining_gas, %EVM.SubState{}, exec_env, data}
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  @spec exp_mod(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exp_mod(gas, exec_env) do
    length_data = Memory.read_zeroed_memory(exec_env.data, 0, 96)

    <<b_length_bin::binary-size(32), e_length_bin::binary-size(32),
      m_length_bin::binary-size(32)>> = length_data

    b_length = :binary.decode_unsigned(b_length_bin)
    e_length = :binary.decode_unsigned(e_length_bin)
    m_length = :binary.decode_unsigned(m_length_bin)

    if b_length <= 24_577 && e_length <= 24_577 && m_length <= 24_577 do
      data = Memory.read_zeroed_memory(exec_env.data, 96, b_length + e_length + m_length)

      <<b_bin::binary-size(b_length), e_bin::binary-size(e_length), m_bin::binary-size(m_length)>> =
        data

      b = :binary.decode_unsigned(b_bin)
      e = :binary.decode_unsigned(e_bin)
      m = :binary.decode_unsigned(m_bin)

      required_gas =
        round(
          f(max(b_length, m_length)) *
            max(e_length_prime(e_length, e, {exec_env.data, b_length}), 1) / @g_quaddivisor
        )

      if required_gas <= gas do
        result =
          cond do
            m == 0 -> 0
            b == 0 -> 0
            e == 0 -> 1
            true -> :crypto.mod_pow(b, e, m)
          end
          |> :binary.encode_unsigned()

        remaining_gas = gas - required_gas

        {remaining_gas, %EVM.SubState{}, exec_env, result}
      else
        {0, %EVM.SubState{}, exec_env, :failed}
      end
    else
      {0, %EVM.SubState{}, exec_env, :failed}
    end
  end

  def f(x) when x <= 64, do: x * x

  def f(x) when x > 64 and x <= 1024 do
    MathHelper.floor(x * x / 4) + 96 * x - 3_072
  end

  def f(x) do
    MathHelper.floor(x * x / 16) + 480 * x - 199_680
  end

  def e_length_prime(e_length, e, _) when e == 0 and e_length <= 32, do: 0

  def e_length_prime(e_length, e, _) when e != 0 and e_length <= 32 do
    e
    |> :math.log2()
    |> MathHelper.floor()
  end

  def e_length_prime(e_length, _e, {data, b_length}) do
    b_length_data =
      data
      |> Memory.read_zeroed_memory(96 + b_length, 32)
      |> :binary.decode_unsigned()

    if e_length > 32 && b_length_data != 0 do
      8 * (e_length - 32) + MathHelper.floor(:math.log2(b_length_data))
    else
      8 * (e_length - 32)
    end
  end
end
