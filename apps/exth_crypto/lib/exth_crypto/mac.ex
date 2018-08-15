defmodule ExthCrypto.MAC do
  @moduledoc """
  Wrapper for erlang's built-in HMAC (Hash-based Message Authentication Code)
  and CMAC (Cipher-based Message Authentication Code) routines, to be used for Exthereum.
  """

  alias ExthCrypto.Hash

  @type mac :: binary()
  @type mac_type :: :kec | :fake
  @type mac_inst :: {mac_type, any()}

  defp mac_module(:kec), do: ExthCrypto.Hash.Keccak
  defp mac_module(:fake), do: ExthCrypto.Hash.Fake

  @doc """
  Calcluates the MAC of a given set of input.

  ## Examples

      iex> ExthCrypto.MAC.mac("The quick brown fox jumps over the lazy dog", "key", :sha256) |> ExthCrypto.Math.bin_to_hex
      "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8"

      iex> ExthCrypto.MAC.mac("The quick brown fox jumps over the lazy dog", "key", :sha256, 8)
      <<247, 188, 131, 244, 48, 83, 132, 36>>
  """
  @spec mac(iodata(), iodata(), Hash.hash_algorithm(), integer() | nil) :: mac
  def mac(data, key, hash_algorithm, length \\ nil) when is_atom(hash_algorithm) do
    if Enum.member?(Hash.hash_algorithms(), hash_algorithm) do
      case length do
        nil -> :crypto.hmac(hash_algorithm, key, data)
        _ -> :crypto.hmac(hash_algorithm, key, data, length)
      end
    end

    # TODO: Implement CMAC
  end

  @doc """
  Initializes a new mac of given type with given args.
  """
  @spec init(mac_type) :: mac_inst
  def init(mac_type, args \\ []) do
    {mac_type, apply(mac_module(mac_type), :init_mac, args)}
  end

  @doc """
  Updates a given mac stream with the given secret and data, returning a new mac stream.

  ## Examples

      iex> mac = ExthCrypto.MAC.init(:kec)
      ...> |> ExthCrypto.MAC.update("data")
      iex> is_nil(mac)
      false
  """
  @spec update(mac_inst, binary()) :: mac_inst
  def update({mac_type, mac}, data) do
    {mac_type, mac_module(mac_type).update_mac(mac, data)}
  end

  @doc """
  Finalizes a given mac stream to produce the current hash.

  ## Examples

      iex> ExthCrypto.MAC.init(:kec)
      ...> |> ExthCrypto.MAC.update("data")
      ...> |> ExthCrypto.MAC.final()
      ...> |> ExthCrypto.Math.bin_to_hex
      "8f54f1c2d0eb5771cd5bf67a6689fcd6eed9444d91a39e5ef32a9b4ae5ca14ff"

      iex> ExthCrypto.MAC.init(:fake, ["jedi"])
      ...> |> ExthCrypto.MAC.update(" ")
      ...> |> ExthCrypto.MAC.update("knight")
      ...> |> ExthCrypto.MAC.final()
      "jedi"
  """
  @spec final(mac_inst) :: binary()
  def final({mac_type, mac}) do
    mac_module(mac_type).final_mac(mac)
  end
end
