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

      iex> {:ok, enc} = ExCrypto.ECIES.encrypt(ExCrypto.Test.public_key(:key_a), "hello", "shared_info_1", "shared_info_2", ExCrypto.Test.key_pair(:key_b), ExCrypto.Test.init_vector)
      iex> enc |> ExCrypto.Math.bin_to_hex
      "04049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10c2cabca3626e6bde90ada8207750d42a1bcb2da86ba4e3b633284fe32e2ccdcd90ec51141e9a8c946a20b6e00b35ef35"

      # TODO: More tests
      # TODO: Correct AES cipher?
  """
  @spec encrypt(ExCrypto.public_key, Cipher.plaintext, binary(), binary(), {ExCrypto.public_key, ExCrypto.private_key} | nil, Cipher.init_vector | nil) :: {:ok, binary()} | {:error, String.t}
  def encrypt(her_static_public_key, message, shared_info_1, shared_info_2, my_ephemeral_key_pair \\ nil, init_vector \\ nil) do
    params = Parameters.ecies_aes128_sha256() # TODO: Why?
    key_len = params.key_len
    block_size = Parameters.block_size(params)

    # First, create a new ephemeral key pair (SEC1 - §5.1.3 - Step 1)
    {my_ephemeral_public_key, my_ephemeral_private_key} = case my_ephemeral_key_pair do
      {my_ephemeral_public_key, my_ephemeral_private_key} -> {my_ephemeral_public_key, my_ephemeral_private_key}
      nil -> ECDH.new_ecdh_keypair(@curve_name)
    end

    init_vector = if init_vector, do: init_vector, else: ExCrypto.Cipher.generate_init_vector(key_len)

    # SEC1 - §5.1.3 - Step 2
    # No point compression.

    # SEC1 - §5.1.3 - Steps 3, 4
    # Next, generate our ECDH shared secret (no co-factor)
    shared_secret = ECDH.generate_shared_secret(my_ephemeral_private_key, her_static_public_key, @curve_name)

    # Next, derive a KDF twice the length as needed, with shared_info_1 as the extra_data
    # SEC1 - §5.1.3 - Step 5
    kdf = ExCrypto.KDF.NistSp80056.single_step_kdf(shared_secret, 2 * params.key_len, Hash.kec, shared_info_1)

    # The first half becomes the encoded key, the second half becomes a mac
    with {:ok, derived_keys} <- kdf do
      # SEC1 - §5.1.3 - Step 6
      <<key_enc::binary-size(key_len), key_mac::binary-size(key_len)>> = derived_keys

      # Now, encrypt the message with our encoded key
      # SEC1 - §5.1.3 - Step 7
      encoded_message = Cipher.encrypt(message, key_enc, init_vector, params.cipher)

      # Assert encoded message is the right length
      if byte_size(encoded_message) != key_len do
        {:error, "encoded message incorrect size (#{byte_size(encoded_message)} versus #{block_size})"}
      else
        # Hash the key mac
        key_mac_hashed = Hash.hash(key_mac, params.hasher)

        # Tag the messsage and shared_info_2 data
        message_tag = MAC.mac(encoded_message <> shared_info_2, key_mac_hashed, params.mac)

        # return 0x04 || R || AsymmetricEncrypt(shared-secret, plaintext) || tag
        {:ok, <<0x04>> <> my_ephemeral_public_key <> init_vector <> encoded_message <> message_tag}
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

      iex> ecies_encoded_msg = "04049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10c2cabca3626e6bde90ada8207750d42a1bcb2da86ba4e3b633284fe32e2ccdcd90ec51141e9a8c946a20b6e00b35ef35" |> ExCrypto.Math.hex_to_bin
      iex> ExCrypto.ECIES.decrypt(ExCrypto.Test.private_key(:key_a), ecies_encoded_msg, "shared_info_1", "shared_info_2")
      {:ok, <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> <> "hello"}
  """
  @spec decrypt(ExCrypto.private_key, binary(), binary(), binary()) :: {:ok, Cipher.plaintext} | {:error, String.t}
  def decrypt(my_static_private_key, ecies_encoded_msg, shared_info_1, shared_info_2) do
    params = Parameters.ecies_aes128_sha256() # TODO: Why?

    # Get size of key len, block size and hash len, all in bits
    header_size = 1
    header_size_bits = header_size * 8
    key_len = params.key_len
    private_key_len = byte_size(my_static_private_key)
    public_key_len = 1 + private_key_len * 2 # based on DER encoding
    hash_len = Parameters.hash_len(params)
    encoded_message_len = byte_size(ecies_encoded_msg) - header_size - public_key_len - key_len - hash_len

    # Decode the ECIES encoded message
    case ecies_encoded_msg do
      # SEC1 - §5.1.4 - Step 1
      # Note, we only allow 0x04 as the header byte
      <<
          0x04::size(header_size_bits),                          # header
          her_ephemeral_public_key::binary-size(public_key_len), # public key
          cipher_iv::binary-size(key_len),                       # cipher iv
          encoded_message::binary-size(encoded_message_len),     # encoded_message
          message_tag::binary-size(hash_len)>> ->                # message tag

        # TODO: SEC1 - §5.1.4 - Steps 2, 3 - Verify curve

        # SEC1 - §5.1.4 - Steps 4, 5
        # Generate a shared secret based on our ephemeral private key and the ephemeral public key from the message
        shared_secret = ECDH.generate_shared_secret(my_static_private_key, her_ephemeral_public_key, @curve_name)

        # SEC1 - §5.1.4 - Step 6
        # Geneate our KDF as before
        kdf = ExCrypto.KDF.NistSp80056.single_step_kdf(shared_secret, 2 * params.key_len, Hash.kec, shared_info_1)

        # The first half becomes the encoded key, the second half becomes a mac
        with {:ok, derived_keys} <- kdf do

          # SEC1 - §5.1.4 - Step 7
          <<key_enc::binary-size(key_len), key_mac::binary-size(key_len)>> = derived_keys

          # Hash the key mac
          key_mac_hashed = Hash.hash(key_mac, params.hasher)

          # SEC1 - §5.1.4 - Step 8
          # Tag the messsage and shared_info_2 data
          generated_message_tag = MAC.mac(encoded_message <> shared_info_2, key_mac_hashed, params.mac)

          unless message_tag == generated_message_tag do
            {:error, "Invalid message tag"}
          else
            # SEC1 - §5.1.4 - Step 9
            message = Cipher.decrypt(encoded_message, key_enc, cipher_iv, params.cipher)

            # SEC1 - §5.1.4 - Step 10
            {:ok, message}
          end
        end
      _els -> {:error, "Invalid ECIES encoded message"}
    end
  end

end