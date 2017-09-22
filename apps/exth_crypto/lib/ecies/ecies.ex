defmodule ExCrypto.ECIES do
  @moduledoc """
  Defines ECIES, as it pertains to Ethereum.
  """

  alias ExCrypto.ECIES.ECDH

  @curve :secp256k1

  # Currently ECIES_AES128_SHA256
  @params %{
    hash: ExCrypto.SHA.SHA256/1,
    cipher: ExCrpyto.AES.encrypt/1,
    block_size: ExCrpyto.AES.block_size,
    key_len: 16
  }

  @doc """
  Encrypts a message according to ECIES specification.

  ## Examples

      iex> 
  """
  @spec encrypt(ExCrypto.public_key, binary(), binary(), binary()) :: binary()
  def encrypt(public_key, message, s1, s2) do
    {_, ephemeral_private_key} = ECDH.new_ecdh_keypair(@curve)
    shared_secret = ECDH.generate_shared_secret(ephemeral_private_key, public_key, @curve)
    key_data_len = @params[:key_len] + @params[:key_len] # Why?

    kdf = ExCrypto.KDF.NistSp80056.single_step_kdf(shared_secret, key_data_len, &ExCrypto.Keccak/1, nil, 256, s1)

    with {:ok, <<key_m::size(key_len), key_e::size(key_len)>>} <- kdf do
      
    end
  end
end