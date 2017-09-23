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

      iex> ExCrypto.MAC.mac("hi", "key", :sha256)
      <<>>

      iex> ExCrypto.MAC.mac("hi", "key", :sha256, 64)
      <<>>
  """
  @spec mac(iodata(), iodata(), Hash.hash_algorithm, integer()) :: mac
  def mac(data, key, hash_algorithm, length \\ nil) when is_atom(hash_algorithm) do
    cond do
      Enum.member?(Hash.hash_algorithms, hash_algorithm) ->
        :crypto.hmac(hash_algorithm, key, data, length)
      # TODO: Implement CMAC
    end
  end
end