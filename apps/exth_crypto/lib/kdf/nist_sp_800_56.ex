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

  ## Examples

      iex> ExCrypto.KDF.NistSp80056("secret", 5, {ExCrypto.SHA.sha1, nil, 20}, "extra")
      <<>>
  """
  @spec single_step_kdf(binary(), integer(), ExCrypto.hash_type, binary()) :: {:ok, binary()} | {:error, String.t}
  def single_step_kdf(shared_secret, key_data_len, {hasher, hash_in_max_len, hash_out_len}, extra_data \\ <<>>) do
    reps = round(:math.ceil(key_data_len / hash_out_len))
    key_data_len_bits = key_data_len * 8

    cond do
      key_data_len < hash_out_len * @max_32_int -> {:error, "Key data is too large"}
      reps > @max_32_int -> {:error, "Too many reps required"}
      hash_in_max_len and byte_size(shared_secret <> extra_data) + 4 > hash_in_max_len -> {:error, "Concatenation of counter, shared_secret and extra_data too large"}
      true ->
        {derived_keying_material_padded, _} = Enum.reduce(1..reps, {<<>>, 1}, fn el, {results, counter} do
          counter_enc = :binary.encode_unsigned(counter |> mod(@two_power_32), :big)

          result = hasher.(counter_enc <> shared_secret <> extra_data)

          { results <> result, counter + 1 }
        end)

        <<derived_keying_material::size(key_data_len_bits), _::binary()>> = derived_keying_material_padded

        {:ok, derived_keying_material}
    end
  end
end