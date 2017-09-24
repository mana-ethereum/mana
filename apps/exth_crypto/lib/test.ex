defmodule ExCrypto.Test do
  @moduledoc """
  A variety of helper functions to make the tests consistent
  in their usage of keys, etc.
  """

  @public_keys %{
    key_a: <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
             159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
             171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
             120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>
  }

  @private_keys %{
    key_a: <<94, 217, 126, 139, 193, 247, 132, 35, 174, 8, 191, 12, 133, 229, 115, 237,
             78, 81, 160, 114, 73, 118, 207, 206, 98, 114, 27, 62, 25, 29, 219, 206>>
  }

  @doc """
  Returns a generic elliptic curve public key based on a given curve.
  """
  def public_key(key \\ :key_a) do
    @public_keys[key]
  end

  @doc """
  Returns a generic elliptic curve public key based on a given curve,
  which is paired with the corresponding public key.
  """
  def private_key(key \\ :key_a) do
    @private_keys[key]
  end
end