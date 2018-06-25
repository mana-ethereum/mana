defmodule EVM.Builtin do
  @moduledoc """
  Implements the built-in functions as defined in Appendix E
  of the Yellow Paper. These are contract functions that
  natively exist in Ethereum.

  TODO: Implement and add doc tests.
  """

  alias EthCore.Math

  @g_rip160_base 600
  @g_rip160_byte 120
  @g_sha256 60 + 12
  @g_identity_base 15
  @g_identity_byte 3
  @g_ecrec 3000

  @doc """
  A precompiled contract that recovers a public key from a signed hash
  (Elliptic curve digital signature algorithm public key recovery function)

  ## Examples

      iex> private_key = ExthCrypto.Test.private_key(:key_a)
      iex> public_key = ExthCrypto.Signature.get_public_key(private_key)
      iex> message = EVM.Helpers.left_pad_bytes("hello")
      iex> {signature, _r, _s, v} = ExthCrypto.Signature.sign_digest(message, private_key)
      iex> data = message <>  EVM.Helpers.left_pad_bytes(:binary.encode_unsigned(v)) <> EVM.Helpers.left_pad_bytes(signature)
      iex> ecrec = EVM.Builtin.run_ecrec(4000,  %EVM.ExecEnv{data: data})
      {1000, %EVM.SubState{}, %EVM.ExecEnv{data: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 104, 101, 108, 108, 111,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 157, 88, 212, 26, 211, 54, 10,135, 39, 216, 45, 18, 56,
      139, 206, 1, 202, 210, 233, 112, 182, 237, 152, 142,71, 252, 20, 42, 181,
      196, 121, 188, 66, 40, 156, 155, 181, 241, 89, 27, 137,161, 53, 118, 139,
      69, 170, 196, 68, 105, 219, 150, 55, 123, 44, 129, 192,236, 10, 217, 165,
      239, 137, 223>>}, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41,
      161, 217, 87, 215,159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136,
      72, 160, 207, 161,171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84,
      156, 99, 224, 155,120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106,
      97, 103, 50, 215, 114>>}
      iex> {_, _, _, result} = ecrec
      iex> {:ok, result} == public_key
      true
  """

  @spec run_ecrec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def run_ecrec(gas, exec_env = %EVM.ExecEnv{data: data}) do
    used_gas = @g_ecrec

    if(used_gas < gas) do
      data = EVM.Helpers.right_pad_bytes(data, 128)
      <<h::binary-size(32), v::binary-size(32), r::binary-size(32), s::binary-size(32)>> = data
      signature = r <> s

      case ExthCrypto.Signature.recover(h, signature, :binary.decode_unsigned(v)) do
        {:ok, public_key} ->
          remaining_gas = gas - used_gas
          EVM.Helpers.left_pad_bytes(public_key, 32)
          {remaining_gas, %EVM.SubState{}, exec_env, public_key}

        {:error, _} ->
          {gas, %EVM.SubState{}, exec_env, <<>>}
      end
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
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
    used_gas = @g_sha256 * Math.bits_to_words(byte_size(data))

    if(used_gas < gas) do
      remaining_gas = gas - used_gas
      result = :crypto.hash(:sha256, data)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
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
    used_gas = @g_rip160_base + @g_rip160_byte * Math.bits_to_words(byte_size(data))

    if(used_gas < gas) do
      remaining_gas = gas - used_gas
      result = :crypto.hash(:ripemd160, data) |> EVM.Helpers.left_pad_bytes(32)
      {remaining_gas, %EVM.SubState{}, exec_env, result}
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
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
    used_gas = @g_identity_base + @g_identity_byte * Math.bits_to_words(byte_size(data))

    if(used_gas < gas) do
      remaining_gas = gas - used_gas
      {remaining_gas, %EVM.SubState{}, exec_env, data}
    else
      {gas, %EVM.SubState{}, exec_env, <<>>}
    end
  end
end
