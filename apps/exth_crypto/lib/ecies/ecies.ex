defmodule ExCrypto.ECIES do
  @moduledoc """
  Defines ECIES, as it pertains to Ethereum.
  """

  alias ExCrypto.ECIES.Parameters
  alias ExCrypto.ECIES.ECDH
  alias ExCrypto.MAC
  alias ExCrypto.Hash
  alias ExCrypto.Cipher

  @curve_name :secp256k1

  @doc """
  Encrypts a message according to ECIES specification.

  ECIES Encrypt, where P = recipient public key is:
  ```
    1) generate r = random value
    2) generate shared-secret = kdf( ecdhAgree(r, P) )
    3) generate R = rG [same op as generating a public key]
    4) send 0x04 || R || AsymmetricEncrypt(shared-secret, plaintext) || tag
  ```

  ## Examples

      iex> ephemeral_public_key = <<1::160>>
      iex> ExCrypto.ECIES.encrypt(ephemeral_public_key, "hello", "s1", "s2")
      {:ok, <<>>}
  """
  @spec encrypt(ExCrypto.public_key, Cipher.plaintext, binary(), binary()) :: {:ok, binary()} | {:error, String.t}
  def encrypt(public_key, message, s1, s2) do
    params = Parameters.ecies_aes128_sha256() # TODO: Why?
    key_len_bits = params.key_len * 8

    # First, create a new ehpemeral key
    {ephemeral_public_key, ephemeral_private_key} = ECDH.new_ecdh_keypair(@curve_name)

    # Next, generate our ECDH shared secret
    shared_secret = ECDH.generate_shared_secret(ephemeral_private_key, public_key, @curve_name)

    # Next, derive a KDF twice the length as needed, with s1 as the extra_data
    kdf = ExCrypto.KDF.NistSp80056.single_step_kdf(shared_secret, 2 * params.key_len, Hash.kec, s1)

    # The first half becomes the encoded key, the second half becomes a mac
    with {:ok, <<key_enc::size(key_len_bits), key_mac::size(key_len_bits)>>} <- kdf do

      # Now, encrypt the message with our encoded key
      {encoded_message, cipher_iv} = Cipher.encrypt(message, key_enc, params.cipher)

      # Assert encoded message is the right length
      if byte_size(encoded_message) <= params.block_size do
        {:error, "encoded message too short"}
      else
        # Hash the key mac
        key_mac_hashed = Hash.hash(key_mac, params.hasher)

        # Tag the messsage and s2 data
        message_tag = MAC.mac(encoded_message <> s2, key_mac_hashed, params.mac)

        # return 0x04 || R || AsymmetricEncrypt(shared-secret, plaintext) || tag
        {:ok, <<0x04>> <> ephemeral_public_key <> cipher_iv <> encoded_message <> message_tag}
      end
    end
  end

  @doc """
  Decrypts a message according to ECIES specification.

  ECIES Decrypt (performed by recipient):
  ```
    1) generate shared-secret = kdf( ecdhAgree(myPrivKey, msg[1:65]) )
    2) verify tag
    3) decrypt

    ecdhAgree(r, recipientPublic) == ecdhAgree(recipientPrivate, R)
    [where R = r*G, and recipientPublic = recipientPrivate*G]
  ```

  ## Examples

      iex> ephemeral_private_key = <<1::160>>
      iex> encoded_message = <<1, 2, 3>>
      iex> ExCrypto.ECIES.decrypt(ephemeral_private_key, encoded_message, "s1", "s2")
      {:ok, <<>>}
  """
  @spec decrypt(ExCrypto.private_key, binary(), binary(), binary()) :: {:ok, Cipher.plaintext} | {:error, String.t}
  def decrypt(ephemeral_private_key, ecies_encoded_msg, s1, s2) do
    params = Parameters.ecies_aes128_sha256() # TODO: Why?

    # Get size of key len, block size and hash len, all in bits
    header_size_bits = 8
    key_len_bits = params.key_len * 8
    block_size_bits = Parameters.block_size(params) * 8
    hash_len_bits = Parameters.hash_len(params) * 8
    encoded_message_bits = byte_size(ecies_encoded_msg) * 8 - header_size_bits - key_len_bits - block_size_bits - hash_len_bits

    # Decode the ECIES encoded message
    case ecies_encoded_msg do
      <<
          0x04::size(header_size_bits),                # header
          ephemeral_public_key::size(key_len_bits),    # public key
          cipher_iv::size(block_size_bits),            # cipher iv
          encoded_message::size(encoded_message_bits), # encoded_message
          message_tag::size(hash_len_bits)>> ->        # message tag

        # Generate a shared secret based on our ephemeral private key and the ephemeral public key from the message
        shared_secret = ECDH.generate_shared_secret(ephemeral_private_key, ephemeral_public_key, @curve_name)

        # Geneate our KDF as before
        kdf = ExCrypto.KDF.NistSp80056.single_step_kdf(shared_secret, 2 * params.key_len, Hash.kec, s1)

        # The first half becomes the encoded key, the second half becomes a mac
        with {:ok, <<key_enc::size(key_len_bits), key_mac::size(key_len_bits)>>} <- kdf do
          # Hash the key mac
          key_mac_hashed = Hash.hash(key_mac, params.hasher)

          # Tag the messsage and s2 data
          generated_message_tag = MAC.mac(encoded_message <> s2, key_mac_hashed, params.mac)

          unless message_tag == generated_message_tag do
            {:error, "Invalid message tag"}
          else
            message = Cipher.decrypt(encoded_message, key_enc, cipher_iv, params.cipher)

            {:ok, message}
          end
        end
      _els -> {:error, "Invalid ECIES encoded message"}
    end
  end

end