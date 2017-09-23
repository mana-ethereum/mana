defmodule ExCrypto.ECIES.ECDH do
  @moduledoc """
  Implements Elliptic Curve Diffie-Hellman, as it pertains to Exthereum.
  """

  @doc """
  Generates a new keypair for elliptic curve diffie-hellman.

  These keys should be used as ephemeral keys in the key-exchange protocol.

  ## Examples

      iex> ExCrypto.ECIES.ECDH.new_ecdh_keypair(:secp256k1)
      {<<>>, <<>>}
  """
  @spec new_ecdh_keypair(ExCrypto.named_curve) :: {ExCrypto.public_key, ExCrpyto.private_key}
  def new_ecdh_keypair(curve) when is_atom(curve) do
    :crypto.generate_key(:ecdh, curve)
  end

  @doc """
  Generates a static shared secret between two parties according to the
  protocol for elliptic curve diffie hellman.

  ## Examples

      iex> {_, my_private_key} = ExCrypto.ECIES.ECDH.new_ecdh_keypair(:secp256k1)
      iex> {her_public_key, _} = ExCrypto.ECIES.ECDH.new_ecdh_keypair(:secp256k1)
      iex> ExCrypto.ECIES.ECDH.generate_shared_secret(my_private_key, her_public_key, :secp256k1)
      <<>>
  """
  @spec generate_shared_secret(ExCrypto.private_key, ExCrypto.public_key, ExCrypto.named_curve) :: binary()
  def generate_shared_secret(local_private_key, remote_public_key, curve) when is_atom(curve) do
    :crypto.compute_key(:ecdh, remote_public_key, local_private_key, curve)
  end
end