defmodule ExCrypto.MAC do
  @moduledoc """
  Wrapper for erlang's built-in HMAC (Hash-based Message Authentication Code)
  and CMAC (Cipher-based Message Authentication Code) routines, to be used for Exthereum.
  """

  alias ExCrypto.Hash

  @type mac :: binary()

  @doc """
  Calcluates the MAC of a given set of input.

  ## Examples

      iex> ExCrypto.MAC.mac("The quick brown fox jumps over the lazy dog", "key", :sha256) |> ExCrypto.Math.bin_to_hex
      "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8"

      iex> ExCrypto.MAC.mac("The quick brown fox jumps over the lazy dog", "key", :sha256, 8)
      <<247, 188, 131, 244, 48, 83, 132, 36>>
  """
  @spec mac(iodata(), iodata(), Hash.hash_algorithm, integer()) :: mac
  def mac(data, key, hash_algorithm, length \\ nil) when is_atom(hash_algorithm) do
    cond do
      Enum.member?(Hash.hash_algorithms, hash_algorithm) ->
        case length do
          nil -> :crypto.hmac(hash_algorithm, key, data)
          _ -> :crypto.hmac(hash_algorithm, key, data, length)
        end
      # TODO: Implement CMAC
    end
  end
end