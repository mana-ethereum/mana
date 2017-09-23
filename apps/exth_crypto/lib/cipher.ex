defmodule ExCrypto.Cipher do

  @type cipher :: {atom(), integer()}
  @type plaintext :: iodata()
  @type ciphertext :: binary()
  @type iv :: binary()

  @doc """
  Encrypts the given plaintext for the given block cipher.

  ## Examples

      iex> ExCrypto.Cipher.encrypt("hi", <<1>>, "init", {ExCrypto.AES, ExCrypto.AES.block_size})
      <<>>
  """
  @spec encrypt(plaintext, ExCrypto.public_key, iv, cipher) :: ciphertext
  def encrypt(plaintext, public_key, iv, {mod, _block_size} = _cipher) do
    mod.encrypt(plaintext, public_key, iv)
  end

  @doc """
  Encrypts the given plaintext for the given block cipher, returning both the cipher
  text and the init vector used.

  ## Examples

      iex> ExCrypto.Cipher.encrypt("hi", <<1>>, "init", {ExCrypto.AES, ExCrypto.AES.block_size})
      {<<>>, <<1>>}
  """
  @spec encrypt(plaintext, ExCrypto.public_key, cipher) :: {ciphertext, iv}
  def encrypt(plaintext, public_key, {mod, block_size} = _cipher) do
    iv = :crypto.strong_rand_bytes(block_size)

    {mod.encrypt(plaintext, public_key, iv), iv}
  end

  @doc """
  Decrypts the given ciphertext from the given block cipher.

  ## Examples

      iex> ExCrypto.Cipher.decrypt("hi", <<1>>, "init", {ExCrypto.AES, ExCrypto.AES.block_size})
      <<>>
  """
  @spec decrypt(ciphertext, ExCrypto.private_key, iv, cipher) :: plaintext
  def decrypt(ciphertext, private_key, iv, {mod, _block_size} = _cipher) do
    mod.decrypt(ciphertext, private_key, iv)
  end
end