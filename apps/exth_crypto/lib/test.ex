defmodule ExCrypto.Test do
  @moduledoc """
  A variety of helper functions to make the tests consistent
  in their usage of keys, etc.
  """

  @public_keys %{
    key_a: <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
             159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
             171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
             120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>,
    key_b: <<4, 152, 113, 235, 8, 21, 103, 130, 50, 103, 89, 42, 186, 200, 236, 158, 159,
             221, 253, 236, 231, 144, 26, 21, 242, 51, 181, 63, 48, 77, 120, 96, 104, 108,
             33, 96, 27, 161, 167, 245, 102, 128, 226, 45, 10, 192, 62, 204, 208, 142, 73,
             100, 105, 81, 76, 37, 174, 29, 94, 85, 243, 145, 193, 149, 111>>,
  }

  @private_keys %{
    key_a: <<94, 217, 126, 139, 193, 247, 132, 35, 174, 8, 191, 12, 133, 229, 115, 237,
             78, 81, 160, 114, 73, 118, 207, 206, 98, 114, 27, 62, 25, 29, 219, 206>>,
    key_b: <<226, 137, 30, 163, 26, 230, 61, 203, 158, 81, 58, 4, 197, 149, 169, 80, 34,
             11, 157, 221, 132, 75, 78, 202, 254, 8, 94, 254, 229, 98, 104, 5>>,
  }

  @symmetric_keys %{
    key_a: <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
             22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>,
    key_b: <<11, 22, 33, 44, 55, 66, 77, 88, 99, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
             22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32>>,
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

  def symmetric_key(key \\ :key_a) do
    @symmetric_keys[key]
  end

  @doc """
  Returns an initialization vector of the given size that is specifically
  not random at all (just for testing).
  """
  def init_vector(base \\ 1, block_size \\ 16) do
    for i <- base..(base + block_size - 1), do: <<i>>, into: <<>>
  end
end