defmodule EVM.Builtin.EcPairing do
  alias EVM.Helpers
  alias BN.BN128Arithmetic
  alias BN.{FQ, FQP, FQ2, FQ12, Pairing}

  @g_ec_pairing_point 80_000
  @g_ec_pairing 100_000

  @type point :: BN128Arithmetic.point()
  @type point_pair :: {point(), point()}

  @dialyzer {:no_return, pairing: 1}

  @doc """
  Elliptic curve pairing
  """
  @spec exec(EVM.Gas.t(), EVM.ExecEnv.t()) ::
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()}
  def exec(gas, exec_env) do
    data = exec_env.data
    data_size = byte_size(data)
    pair_size = 192

    number_of_pairs = div(data_size, pair_size)
    required_gas = @g_ec_pairing_point * number_of_pairs + @g_ec_pairing

    cond do
      rem(data_size, pair_size) != 0 ->
        {0, %EVM.SubState{}, exec_env, :failed}

      gas < required_gas ->
        {0, %EVM.SubState{}, exec_env, :failed}

      true ->
        case read_pairs(data) do
          {:error, _} ->
            {0, %EVM.SubState{}, exec_env, :failed}

          {:ok, pairs} ->
            pairing_result = pairing(pairs)
            result = if pairing_result == FQ12.one(), do: 1, else: 0

            output = Helpers.left_pad_bytes(result, 32)

            {gas - required_gas, %EVM.SubState{}, exec_env, output}
        end
    end
  end

  @spec read_pairs(binary()) :: {:ok, [point_pair()]} | {:error, String.t()}
  defp read_pairs(data) do
    binary_pairs = for <<chunk::binary-size(192) <- data>>, do: <<chunk::binary-size(192)>>

    pairs = Enum.map(binary_pairs, &deserialize_pair/1)

    first_error =
      Enum.find(pairs, fn result ->
        case result do
          {:error, _} -> true
          _ -> false
        end
      end)

    first_error || {:ok, pairs}
  end

  @spec deserialize_pair(binary()) :: {:ok, point_pair()} | {:error, String.t()}
  defp deserialize_pair(pair_data) do
    <<x1_bin::binary-size(32), y1_bin::binary-size(32), x2_i_bin::binary-size(32),
      x2_r_bin::binary-size(32), y2_i_bin::binary-size(32),
      y2_r_bin::binary-size(32)>> = pair_data

    x1 = :binary.decode_unsigned(x1_bin)
    y1 = :binary.decode_unsigned(y1_bin)
    x2_i = :binary.decode_unsigned(x2_i_bin)
    x2_r = :binary.decode_unsigned(x2_r_bin)
    y2_i = :binary.decode_unsigned(y2_i_bin)
    y2_r = :binary.decode_unsigned(y2_r_bin)

    if x1 >= FQ.default_modulus() || y1 >= FQ.default_modulus() || x2_i >= FQ.default_modulus() ||
         x2_r >= FQ.default_modulus() || y2_i >= FQ.default_modulus() ||
         y2_r >= FQ.default_modulus() do
      {:error, "some values are bigger than field modulus"}
    else
      point1 = {FQ.new(x1), FQ.new(y1)}
      point2 = {FQ2.new([x2_r, x2_i]), FQ2.new([y2_r, y2_i])}

      cond do
        !BN128Arithmetic.on_curve?(point1) -> {:error, "point1 is not on the curve"}
        !BN128Arithmetic.on_curve?(point2) -> {:error, "point2 is not on the curve"}
        true -> {point1, point2}
      end
    end
  end

  @spec pairing([point_pair]) :: FQP.t()
  defp pairing(points) do
    Enum.reduce(points, FQ12.one(), fn {point1, point2}, acc ->
      pairing_result = Pairing.pairing(point2, point1)

      FQ12.mult(acc, pairing_result)
    end)
  end
end
