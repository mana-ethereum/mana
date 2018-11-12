defmodule ExthCrypto.ECIES.ECDH do
  @moduledoc """
  Implements Elliptic Curve Diffie-Hellman, as it pertains to Mana.
  """

  @default_curve :secp256k1
  alias ExthCrypto.Key

  @doc """
  Generates a new keypair for elliptic curve diffie-hellman.

  These keys should be used as ephemeral keys in the key-exchange protocol.

  ## Examples

      iex> {public_key, private_key} = ExthCrypto.ECIES.ECDH.new_ecdh_keypair()
      iex> byte_size(public_key)
      65
      iex> byte_size(private_key)
      32
      iex> {public_key, private_key} == :crypto.generate_key(:ecdh, :secp256k1, private_key)
      true
  """
  @spec new_ecdh_keypair(ExthCrypto.named_curve()) :: Key.key_pair()
  def new_ecdh_keypair(curve \\ @default_curve) when is_atom(curve) do
    {public_key_der, private_key} = :crypto.generate_key(:ecdh, curve)

    {public_key_der
     |> Key.public_der_key()
     |> Key.public_der_to_raw(), private_key}
  end

  @doc """
  Generates a static shared secret between two parties according to the
  protocol for elliptic curve diffie hellman.

  ## Examples

      iex> ExthCrypto.ECIES.ECDH.generate_shared_secret(ExthCrypto.Test.private_key(:key_b), ExthCrypto.Test.public_key(:key_a), :secp256k1)
      <<68, 139, 102, 172, 32, 159, 198, 236, 33, 216, 132, 22, 62, 46, 163, 215, 53, 40, 177, 14, 51, 94, 155, 151, 21, 226, 9, 254, 153, 48, 112, 226>>

      iex> ExthCrypto.ECIES.ECDH.generate_shared_secret(ExthCrypto.Test.private_key(:key_a), ExthCrypto.Test.public_key(:key_b), :secp256k1)
      <<68, 139, 102, 172, 32, 159, 198, 236, 33, 216, 132, 22, 62, 46, 163, 215, 53, 40, 177, 14, 51, 94, 155, 151, 21, 226, 9, 254, 153, 48, 112, 226>>
  """
  @spec generate_shared_secret(
          Key.private_key(),
          Key.public_key(),
          ExthCrypto.named_curve()
        ) :: binary()
  def generate_shared_secret(local_private_key, remote_public_key, curve \\ @default_curve)
      when is_atom(curve) do
    {:public_der, der_remote_public_key_material} = Key.public_raw_to_der(remote_public_key)

    :crypto.compute_key(
      :ecdh,
      der_remote_public_key_material,
      local_private_key,
      curve
    )
  end
end
