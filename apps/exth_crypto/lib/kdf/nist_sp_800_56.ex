defmodule ExCrypto.KDF.NistSp80056 do
  @moduledoc """
  Implements NIST SP 800-56 Key Deriviation Function,
  as defined in http://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-56Ar2.pdf.

  See Section 5.8.1 "The Single-step Key-Derivation Function"
  """

  import ExCrypto.Math

  @two_power_32 round(:math.pow(2, 32))
  @max_32_int @two_power_32 - 1

  @doc """
  Simples the The Single-step Key-Derivation Function as defined in NISP-SP-800-56.

  Note: we do not currently support HMAC.

  # TODO: Test canonical tests

  ## Examples

      iex> ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 32, ExCrypto.Hash.sha1(), "extra")
      {:ok, <<75, 66, 26, 70, 52, 192, 101, 251, 148, 62, 39, 117, 127, 3, 6, 9, 225, 195, 246, 4, 195, 102, 118, 232, 217, 96, 165, 207, 228, 135, 13, 47>>}

      iex> {:ok, key} = ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 200, ExCrypto.Hash.sha1(), "extra")
      iex> ExCrypto.Math.bin_to_hex(key)
      "4b421a4634c065fb943e27757f030609e1c3f604c36676e8d960a5cfe4870d2f7ffae0d171546bc2f56d7936604e9bde880ae39a70c4a12127a13423e610ced458189deae896642145a583f1a224c87cb0cb85cde1e8cb0beb5e9612e9a1e3197c0df73d05244c5719a983f5d0c932677f8f634f00e4d3f5cd64d745388fe2335004e96f6f409ddf0d1c26854474d6c510d8af17a5812410f5322bb1300cf7b8e5c37d1c0d79a2c41c4c686e0895edc93b4417fdd19474622349d0d13e4c704056508eee3b8ccbbe"
  """
  @spec single_step_kdf(binary(), integer(), ExCrypto.Hash.hash_type, binary()) :: {:ok, binary()} | {:error, String.t}
  def single_step_kdf(shared_secret, key_data_len, {hasher, hash_in_max_len, hash_out_len}, extra_data \\ <<>>) do
    # ((key_len + 7) * 8) / (hash_blocksize * 8)
    reps = round(:math.ceil(key_data_len / hash_out_len))
    key_data_len_bits = key_data_len * 8

    cond do
      key_data_len_bits > hash_out_len * @max_32_int -> {:error, "Key data is too large"}
      reps > @max_32_int -> {:error, "Too many reps required"}
      not is_nil(hash_in_max_len) and byte_size(shared_secret <> extra_data) + 4 > hash_in_max_len -> {:error, "Concatenation of counter, shared_secret and extra_data too large"}
      true ->
        derived_keying_material_padded = Enum.reduce(1..reps, <<>>, fn counter, results ->
          counter_enc = :binary.encode_unsigned(counter |> mod(@two_power_32), :big)

          result = hasher.(counter_enc <> shared_secret <> extra_data)

          results <> result
        end)

        <<derived_keying_material::binary-size(key_data_len), _::binary()>> = derived_keying_material_padded

        {:ok, derived_keying_material}
    end
  end
end