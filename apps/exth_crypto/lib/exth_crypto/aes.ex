defmodule ExthCrypto.AES do
  @moduledoc """
  Defines standard functions for use with AES symmetric cryptography in block mode.
  """

  @block_size 32

  @doc """
  Returns the blocksize for AES encryption when used as block mode encryption.

  ## Examples

      iex> ExthCrypto.AES.block_size
      32
  """
  @spec block_size :: integer()
  def block_size, do: @block_size

  @doc """
  Encrypts a given binary with the given public key. For block mode, this is the
  standard encrypt operation. For streaming mode, this will return the final block
  of the stream.

  Note: for streaming modes, `init_vector` is the same as ICB.

  ## Examples

      iex> ExthCrypto.AES.encrypt("obi wan", :cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<86, 16, 7, 47, 97, 219, 8, 46, 16, 170, 70, 100, 131, 140, 241, 28>>

      iex> ExthCrypto.AES.encrypt("obi wan", :cbc, ExthCrypto.Test.symmetric_key(:key_b), ExthCrypto.Test.init_vector)
      <<219, 181, 173, 235, 88, 139, 229, 61, 172, 142, 36, 195, 83, 203, 237, 39>>

      iex> ExthCrypto.AES.encrypt("obi wan", :cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector(2))
      <<134, 126, 59, 64, 83, 197, 85, 40, 155, 178, 52, 165, 27, 190, 60, 170>>

      iex> ExthCrypto.AES.encrypt("jedi knight", :cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<54, 252, 188, 111, 221, 182, 65, 54, 77, 143, 127, 188, 176, 178, 50, 160>>

      iex> ExthCrypto.AES.encrypt("Did you ever hear the story of Darth Plagueis The Wise? I thought not.", :cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector) |> ExthCrypto.Math.bin_to_hex
      "3ee326e03303a303df6eac828b0bdc8ed67254b44a6a79cd0082bc245977b0e7d4283d63a346744d2f1ecaafca8be906d9f3d27db914d80b601d7e0c598418380e5fe2b48c0e0b8454c6d251f577f28f"

      iex> ExthCrypto.AES.encrypt("obi wan", :ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<32, 99, 57, 7, 64, 82, 28>>

      iex> ExthCrypto.AES.encrypt("obi wan", :ctr, ExthCrypto.Test.symmetric_key(:key_b), ExthCrypto.Test.init_vector)
      <<156, 176, 33, 64, 69, 16, 173>>

      iex> ExthCrypto.AES.encrypt("obi wan", :ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector(2))
      <<214, 99, 7, 241, 219, 189, 178>>

      iex> ExthCrypto.AES.encrypt("jedi knight", :ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<37, 100, 52, 78, 23, 88, 28, 22, 254, 47, 32>>

      iex> ExthCrypto.AES.encrypt("Did you ever hear the story of Darth Plagueis The Wise? I thought not.", :ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector) |> ExthCrypto.Math.bin_to_hex
      "0b6834074e5c075ffc31318cc03cba1fe35648a6f149a74952661473b73570fb98332e31870c111d3ae5ccff2154bd4083a7ee4bfd19bc85eba77835aac4cea881ada2630cdd"

      iex> ExthCrypto.AES.encrypt("jedi knight", :ecb, ExthCrypto.Test.symmetric_key)
      <<98, 60, 215, 107, 189, 132, 176, 63, 62, 225, 92, 13, 70, 53, 187, 240>>
  """
  @spec encrypt(
          ExthCrypto.Cipher.plaintext(),
          ExthCrypto.Cipher.mode(),
          ExthCrypto.Key.symmetric_key(),
          ExthCrypto.Cipher.init_vector()
        ) :: ExthCrypto.Cipher.ciphertext()
  def encrypt(plaintext, :cbc, symmetric_key, init_vector) do
    padding_bits = (16 - rem(byte_size(plaintext), 16)) * 8

    :crypto.block_encrypt(
      :aes_cbc,
      symmetric_key,
      init_vector,
      <<0::size(padding_bits)>> <> plaintext
    )
  end

  def encrypt(plaintext, :ctr, symmetric_key, init_vector) do
    {_state, ciphertext} =
      :crypto.stream_init(:aes_ctr, symmetric_key, init_vector)
      |> :crypto.stream_encrypt(plaintext)

    ciphertext
  end

  @spec encrypt(
          ExthCrypto.Cipher.plaintext(),
          ExthCrypto.Cipher.mode(),
          ExthCrypto.Key.symmetric_key()
        ) :: ExthCrypto.Cipher.ciphertext()
  def encrypt(plaintext, :ecb, symmetric_key) do
    padding_bits = (16 - rem(byte_size(plaintext), 16)) * 8

    :crypto.block_encrypt(:aes_ecb, symmetric_key, <<0::size(padding_bits)>> <> plaintext)
  end

  @doc """
  Decrypts the given binary with the given private key.

  ## Examples

      iex> <<86, 16, 7, 47, 97, 219, 8, 46, 16, 170, 70, 100, 131, 140, 241, 28>>
      ...> |> ExthCrypto.AES.decrypt(:cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<219, 181, 173, 235, 88, 139, 229, 61, 172, 142, 36, 195, 83, 203, 237, 39>>
      ...> |> ExthCrypto.AES.decrypt(:cbc, ExthCrypto.Test.symmetric_key(:key_b), ExthCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<134, 126, 59, 64, 83, 197, 85, 40, 155, 178, 52, 165, 27, 190, 60, 170>>
      ...> |> ExthCrypto.AES.decrypt(:cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector(2))
      <<0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "obi wan"

      iex> <<54, 252, 188, 111, 221, 182, 65, 54, 77, 143, 127, 188, 176, 178, 50, 160>>
      ...> |> ExthCrypto.AES.decrypt(:cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0>> <> "jedi knight"

      iex> "3ee326e03303a303df6eac828b0bdc8ed67254b44a6a79cd0082bc245977b0e7d4283d63a346744d2f1ecaafca8be906d9f3d27db914d80b601d7e0c598418380e5fe2b48c0e0b8454c6d251f577f28f"
      ...> |> ExthCrypto.Math.hex_to_bin
      ...> |> ExthCrypto.AES.decrypt(:cbc, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "Did you ever hear the story of Darth Plagueis The Wise? I thought not."

      iex> <<32, 99, 57, 7, 64, 82, 28>>
      ...> |> ExthCrypto.AES.decrypt(:ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      "obi wan"

      iex> <<156, 176, 33, 64, 69, 16, 173>>
      ...> |> ExthCrypto.AES.decrypt(:ctr, ExthCrypto.Test.symmetric_key(:key_b), ExthCrypto.Test.init_vector)
      "obi wan"

      iex> <<214, 99, 7, 241, 219, 189, 178>>
      ...> |> ExthCrypto.AES.decrypt(:ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector(2))
      "obi wan"

      iex> <<37, 100, 52, 78, 23, 88, 28, 22, 254, 47, 32>>
      ...> |> ExthCrypto.AES.decrypt(:ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      "jedi knight"

      iex> "0b6834074e5c075ffc31318cc03cba1fe35648a6f149a74952661473b73570fb98332e31870c111d3ae5ccff2154bd4083a7ee4bfd19bc85eba77835aac4cea881ada2630cdd"
      ...> |> ExthCrypto.Math.hex_to_bin
      ...> |> ExthCrypto.AES.decrypt(:ctr, ExthCrypto.Test.symmetric_key, ExthCrypto.Test.init_vector)
      "Did you ever hear the story of Darth Plagueis The Wise? I thought not."

      iex> ExthCrypto.AES.decrypt(<<98, 60, 215, 107, 189, 132, 176, 63, 62, 225, 92, 13, 70, 53, 187, 240>>, :ecb, ExthCrypto.Test.symmetric_key)
      <<0, 0, 0, 0, 0>> <> "jedi knight"
  """
  @spec decrypt(
          ExthCrypto.Cipher.ciphertext(),
          ExthCrypto.Cipher.mode(),
          ExthCrypto.Key.symmetric_key(),
          ExthCrypto.Cipher.init_vector()
        ) :: ExthCrypto.Cipher.plaintext()
  def decrypt(ciphertext, :cbc, symmetric_key, init_vector) do
    :crypto.block_decrypt(:aes_cbc, symmetric_key, init_vector, ciphertext)
  end

  def decrypt(ciphertext, :ctr, symmetric_key, init_vector) do
    {_state, plaintext} =
      :crypto.stream_init(:aes_ctr, symmetric_key, init_vector)
      |> :crypto.stream_decrypt(ciphertext)

    plaintext
  end

  @spec decrypt(
          ExthCrypto.Cipher.ciphertext(),
          ExthCrypto.Cipher.mode(),
          ExthCrypto.Key.symmetric_key()
        ) :: ExthCrypto.Cipher.plaintext()
  def decrypt(ciphertext, :ecb, symmetric_key) do
    :crypto.block_decrypt(:aes_ecb, symmetric_key, ciphertext)
  end

  @doc """
  Initializes an AES stream in the given mode with a given
  key and init vector.

  ## Examples

      iex> stream = ExthCrypto.AES.stream_init(:ctr, ExthCrypto.Test.symmetric_key(), ExthCrypto.Test.init_vector)
      iex> is_nil(stream)
      false
  """
  @spec stream_init(
          ExthCrypto.Cipher.mode(),
          ExthCrypto.Key.symmetric_key(),
          ExthCrypto.Cipher.init_vector()
        ) :: ExthCrypto.Cipher.stream()
  def stream_init(:ctr, symmetric_key, init_vector) do
    # IO.inspect(["Have symm key: ", symmetric_key])
    :crypto.stream_init(:aes_ctr, symmetric_key, init_vector)
  end

  @doc """
  Encrypts data with an already initialized AES stream, returning a
  stream with updated state, as well as the ciphertext.

  ## Examples

      iex> stream = ExthCrypto.AES.stream_init(:ctr, ExthCrypto.Test.symmetric_key(), ExthCrypto.Test.init_vector)
      iex> {_stream_2, ciphertext} = ExthCrypto.AES.stream_encrypt("hello", stream)
      iex> ciphertext
      "'d<KX"
  """
  @spec stream_encrypt(ExthCrypto.Cipher.plaintext(), ExthCrypto.Cipher.stream()) ::
          {ExthCrypto.Cipher.stream(), ExthCrypto.Cipher.ciphertext()}
  def stream_encrypt(plaintext, stream) do
    :crypto.stream_encrypt(stream, plaintext)
  end

  @doc """
  Decrypts data from an already initialized AES stream, returning a
  stream with updated state, as well as the plaintext.

  ## Examples

      iex> stream = ExthCrypto.AES.stream_init(:ctr, ExthCrypto.Test.symmetric_key(), ExthCrypto.Test.init_vector)
      iex> {_stream_2, ciphertext} = ExthCrypto.AES.stream_encrypt("hello", stream)
      iex> {_stream_3, plaintext} = ExthCrypto.AES.stream_decrypt(ciphertext, stream)
      iex> plaintext
      "hello"
  """
  @spec stream_decrypt(ExthCrypto.Cipher.ciphertext(), ExthCrypto.Cipher.stream()) ::
          {ExthCrypto.Cipher.stream(), ExthCrypto.Cipher.plaintext()}
  def stream_decrypt(plaintext, stream) do
    :crypto.stream_decrypt(stream, plaintext)
  end
end
