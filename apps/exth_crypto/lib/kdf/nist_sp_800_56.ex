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

      iex> ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 20, ExCrypto.Hash.sha1(), "extra")
      {:ok, ExCrypto.Hash.SHA.sha1(<<0, 0, 0, 1>> <> "secret" <> "extra")}

      iex> <<bytes::binary-size(32), _rest::binary()>> = ExCrypto.Hash.SHA.sha1(<<0, 0, 0, 1>> <> "secret" <> "extra") <> ExCrypto.Hash.SHA.sha1(<<0, 0, 0, 2>> <> "secret" <> "extra")
      iex> {:ok, bytes} == ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 32, ExCrypto.Hash.sha1(), "extra")
      true

      iex> ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 32, ExCrypto.Hash.sha1(), "extra")
      {:ok, <<35, 233, 145, 168, 1, 248, 54, 133, 234, 105, 153, 226, 62, 181,
              40, 209, 153, 239, 241, 41, 16, 157, 216, 219, 15, 132, 68, 116,
              206, 152, 20, 98>>}

      iex> {:ok, key} = ExCrypto.KDF.NistSp80056.single_step_kdf("secret", 200, ExCrypto.Hash.sha1(), "extra")
      iex> ExCrypto.Math.bin_to_hex(key)
      "23e991a801f83685ea6999e23eb528d199eff129109dd8db0f844474ce981462fca2dc108bde378d83d9e714a9964d9cd9b1364a167d98fbfe1f94bc6f606879f9150be2979fe27812b7de86546e1994672038b9493abfb4b959676b5927c75dd9f33489f865a71905100633412d9ae93677ca6b4b3646310550252cf1c30da0f9014c72728a66ce20489ec89c718231f163a359a282ff8f73b65e129a1980e130d58cb88d3b041eb29ea69561f0b24b80cb7f421042edf07374bfa553be44ee6b5bf4459de8ef2a"
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
          counter_enc = :binary.encode_unsigned(counter |> mod(@two_power_32), :big) |> ExCrypto.Math.pad(4)

          result = hasher.(counter_enc <> shared_secret <> extra_data)

          results <> result
        end)

        <<derived_keying_material::binary-size(key_data_len), _::binary()>> = derived_keying_material_padded

        {:ok, derived_keying_material}
    end
  end
end