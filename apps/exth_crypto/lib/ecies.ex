defmodule ExthCrypto.ECIES do
  @moduledoc """
  Defines ECIES, as it pertains to Ethereum.

  This is derived primarily from [SEC 1: Elliptic Curve Cryptography](http://www.secg.org/sec1-v1.99.dif.pdf)
  """

  alias ExthCrypto.ECIES.Parameters
  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.MAC
  alias ExthCrypto.Hash
  alias ExthCrypto.Cipher

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

      iex> {:ok, enc} = ExthCrypto.ECIES.encrypt(ExthCrypto.Test.public_key(:key_a), "hello", "shared_info_1", "shared_info_2", ExthCrypto.Test.key_pair(:key_b), ExthCrypto.Test.init_vector)
      iex> enc |> ExthCrypto.Math.bin_to_hex
      "049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10a6c88ba08a258e9e5b5124997ee1b502570f933d4fc0b48cef5a504749e4eac1a56f3211de"

      # Test overhead is exactly 113 bytes
      iex> msg = "The quick brown fox jumped over the lazy dog."
      iex> {:ok, enc} = ExthCrypto.ECIES.encrypt(ExthCrypto.Test.public_key(:key_a), msg, "shared_info_1", "shared_info_2", ExthCrypto.Test.key_pair(:key_b), ExthCrypto.Test.init_vector)
      iex> byte_size(enc) - byte_size(msg)
      113

      # TODO: More tests
  """
  @spec encrypt(
          ExthCrypto.Key.public_key(),
          Cipher.plaintext(),
          binary(),
          binary(),
          {ExthCrypto.Key.public_key(), ExthCrypto.Key.private_key()} | nil,
          Cipher.init_vector() | nil
        ) :: {:ok, binary()} | {:error, String.t()}
  def encrypt(
        her_static_public_key,
        message,
        shared_info_1 \\ <<>>,
        shared_info_2 \\ <<>>,
        my_ephemeral_key_pair \\ nil,
        init_vector \\ nil
      ) do
    # Question, is this always the parameters? If not, how do we choose?
    params = Parameters.ecies_aes128_sha256()
    key_len = params.key_len

    # First, create a new ephemeral key pair (SEC1 - §5.1.3 - Step 1)
    {my_ephemeral_public_key, my_ephemeral_private_key} =
      case my_ephemeral_key_pair do
        {my_ephemeral_public_key, my_ephemeral_private_key} ->
          {my_ephemeral_public_key, my_ephemeral_private_key}

        nil ->
          ECDH.new_ecdh_keypair(@curve_name)
      end

    init_vector = if init_vector, do: init_vector, else: Cipher.generate_init_vector(key_len)

    # SEC1 - §5.1.3 - Step 2
    # No point compression.

    # SEC1 - §5.1.3 - Steps 3, 4
    # Next, generate our ECDH shared secret (no co-factor)
    shared_secret =
      ECDH.generate_shared_secret(my_ephemeral_private_key, her_static_public_key, @curve_name)

    # Next, derive a KDF twice the length as needed, with shared_info_1 as the extra_data
    # SEC1 - §5.1.3 - Step 5
    kdf =
      ExthCrypto.KDF.NistSp80056.single_step_kdf(
        shared_secret,
        2 * params.key_len,
        params.hasher,
        shared_info_1
      )

    # The first half becomes the encoded key, the second half becomes a mac
    with {:ok, derived_keys} <- kdf do
      # SEC1 - §5.1.3 - Step 6
      <<key_enc::binary-size(key_len), key_mac::binary-size(key_len)>> = derived_keys

      # Now, encrypt the message with our encoded key
      # SEC1 - §5.1.3 - Step 7
      encoded_message = Cipher.encrypt(message, key_enc, init_vector, params.cipher)

      # Hash the key mac
      key_mac_hashed = Hash.hash(key_mac, params.hasher)

      # Tag the messsage and shared_info_2 data
      message_tag =
        MAC.mac(init_vector <> encoded_message <> shared_info_2, key_mac_hashed, params.mac)

      # Remove DER encoding byte
      my_ephemeral_public_key_raw = ExthCrypto.Key.der_to_raw(my_ephemeral_public_key)

      # return 0x04 || R || AsymmetricEncrypt(shared-secret, plaintext) || tag
      {:ok,
       <<0x04>> <> my_ephemeral_public_key_raw <> init_vector <> encoded_message <> message_tag}
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

      iex> ecies_encoded_msg = "049871eb081567823267592abac8ec9e9fddfdece7901a15f233b53f304d7860686c21601ba1a7f56680e22d0ac03eccd08e496469514c25ae1d5e55f391c1956f0102030405060708090a0b0c0d0e0f10a6c88ba08a258e9e5b5124997ee1b502570f933d4fc0b48cef5a504749e4eac1a56f3211de" |> ExthCrypto.Math.hex_to_bin
      iex> ExthCrypto.ECIES.decrypt(ExthCrypto.Test.private_key(:key_a), ecies_encoded_msg, "shared_info_1", "shared_info_2")
      {:ok, "hello"}
  """
  @spec decrypt(ExthCrypto.Key.private_key(), binary(), binary(), binary()) ::
          {:ok, Cipher.plaintext()} | {:error, String.t()}
  def decrypt(
        my_static_private_key,
        ecies_encoded_msg,
        shared_info_1 \\ <<>>,
        shared_info_2 \\ <<>>
      ) do
    # Question, is this always the parameters? If not, how do we choose?
    params = Parameters.ecies_aes128_sha256()

    # Get size of key len, block size and hash len, all in bits
    header_size = 1
    header_size_bits = header_size * 8
    key_len = params.key_len
    private_key_len = byte_size(my_static_private_key)
    public_key_len = private_key_len * 2
    hash_len = Parameters.hash_len(params)

    encoded_message_len =
      byte_size(ecies_encoded_msg) - header_size - public_key_len - key_len - hash_len

    # Decode the ECIES encoded message
    case ecies_encoded_msg do
      # SEC1 - §5.1.4 - Step 1
      # Note, we only allow 0x04 as the header byte
      <<
        # header
        0x04::size(header_size_bits),
        # public key
        her_ephemeral_public_key_raw::binary-size(public_key_len),
        # cipher iv
        cipher_iv::binary-size(key_len),
        # encoded_message
        encoded_message::binary-size(encoded_message_len),
        # message tag
        message_tag::binary-size(hash_len)
      >> ->
        # TODO: SEC1 - §5.1.4 - Steps 2, 3 - Verify curve

        # SEC1 - §5.1.4 - Steps 4, 5
        # Generate a shared secret based on our ephemeral private key and the ephemeral public key from the message
        her_ephemeral_public_key = ExthCrypto.Key.raw_to_der(her_ephemeral_public_key_raw)

        shared_secret =
          ECDH.generate_shared_secret(
            my_static_private_key,
            her_ephemeral_public_key,
            @curve_name
          )

        # SEC1 - §5.1.4 - Step 6
        # Geneate our KDF as before
        kdf =
          ExthCrypto.KDF.NistSp80056.single_step_kdf(
            shared_secret,
            2 * params.key_len,
            params.hasher,
            shared_info_1
          )

        # The first half becomes the encoded key, the second half becomes a mac
        with {:ok, derived_keys} <- kdf do
          # SEC1 - §5.1.4 - Step 7
          <<key_enc::binary-size(key_len), key_mac::binary-size(key_len)>> = derived_keys

          # Hash the key mac
          key_mac_hashed = Hash.hash(key_mac, params.hasher)

          # SEC1 - §5.1.4 - Step 8
          # Tag the messsage and shared_info_2 data
          generated_message_tag =
            MAC.mac(cipher_iv <> encoded_message <> shared_info_2, key_mac_hashed, params.mac)

          if message_tag == generated_message_tag do
            # SEC1 - §5.1.4 - Step 9
            message = Cipher.decrypt(encoded_message, key_enc, cipher_iv, params.cipher)

            # SEC1 - §5.1.4 - Step 10
            {:ok, message}
          else
            {:error, "Invalid message tag"}
          end
        end

      _els ->
        {:error, "Invalid ECIES encoded message"}
    end
  end
end
