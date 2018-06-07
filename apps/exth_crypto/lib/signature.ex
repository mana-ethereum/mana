defmodule ExthCrypto.Signature do
  @moduledoc """
  A variety of functions for calculating cryptographic signatures.

  Right now these all rely on the `libsecp256k1` library, and thus only
  performs signatures on this Elliptic Curve, but I don't see any reason
  why we couldn't switch to standard libraries if they provide similar
  functionality.
  """

  # 512 = 64 * 8
  @type signature :: <<_::512>>
  @type r :: integer()
  @type s :: integer()
  @type recovery_id :: 0..3
  # 520 = (64 + 1) * 8
  @type compact_signature :: <<_::520>>

  @signature_length 64

  @doc """
  Given a private key, returns a public key.

  ## Examples

      iex> ExthCrypto.Signature.get_public_key(ExthCrypto.Test.private_key)
      {:ok, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
             159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
             171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
             120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>}

      iex> ExthCrypto.Signature.get_public_key(<<1>>)
      {:error, "Private key size not 32 bytes"}
  """
  @spec get_public_key(ExthCrypto.Key.private_key()) ::
          {:ok, ExthCrypto.Key.public_key()} | {:error, String.t()}
  def get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Computes an ECDSA signature of the given (already digested) data.

  This returns both the `r` and `s` results, the recovery id, and the
  concatenated signature `sig`.

  ## Examples

      iex> {signature, _r, _s, _recovery_id} = ExthCrypto.Signature.sign_digest("12345", ExthCrypto.Test.private_key)
      iex> ExthCrypto.Signature.verify("12345", signature, ExthCrypto.Test.public_key)
      true
  """
  @spec sign_digest(binary(), ExthCrypto.Key.private_key()) :: {signature, r, s, recovery_id}
  def sign_digest(digest, private_key) do
    {:ok, <<r::size(256), s::size(256)>> = signature, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(digest, private_key, :default, <<>>)

    {signature, r, s, recovery_id}
  end

  @doc """
  Verifies a that a given signature for a given digest is valid against a public key.

  ## Examples

      iex> msg = ExthCrypto.Math.nonce(32)
      iex> {signature, _r, _s, _recovery_id} = ExthCrypto.Signature.sign_digest(msg, ExthCrypto.Test.private_key(:key_a))
      iex> ExthCrypto.Signature.verify(msg, signature, ExthCrypto.Test.public_key(:key_a))
      true

      iex> msg = ExthCrypto.Math.nonce(32)
      iex> {signature, _r, _s, _recovery_id} = ExthCrypto.Signature.sign_digest(msg, ExthCrypto.Test.private_key(:key_a))
      iex> ExthCrypto.Signature.verify(msg, signature, ExthCrypto.Test.public_key(:key_b))
      false

      iex> msg = ExthCrypto.Math.nonce(32)
      iex> {signature, _r, _s, _recovery_id} = ExthCrypto.Signature.sign_digest(msg, ExthCrypto.Test.private_key(:key_a))
      iex> ExthCrypto.Signature.verify(msg |> Binary.drop(1), signature, ExthCrypto.Test.public_key(:key_a))
      false
  """
  @spec verify(binary(), signature, ExthCrypto.Key.public_key()) :: boolean()
  def verify(digest, signature, public_key) do
    case :libsecp256k1.ecdsa_verify_compact(digest, signature, public_key) do
      :ok -> true
      :error -> false
    end
  end

  @doc """
  Recovers a public key from a given signature for a given digest.

  Note, the key is returned in DER format (with a leading 0x04 to indicate
  that it's an octet-string).

  ## Examples

      iex> msg = ExthCrypto.Math.nonce(32)
      iex> {signature, _r, _s, recovery_id} = ExthCrypto.Signature.sign_digest(msg, ExthCrypto.Test.private_key(:key_a))
      iex> ExthCrypto.Signature.recover(msg, signature, recovery_id)
      {:ok, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
              159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
              171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
              120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>}

      iex> {signature, _r, _s, recovery_id} = ExthCrypto.Signature.sign_digest(msg = ExthCrypto.Math.nonce(32), ExthCrypto.Test.private_key(:key_a))
      iex> ExthCrypto.Signature.recover(msg, signature, recovery_id)
      {:ok, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
              159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
              171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
              120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>}
  """
  @spec recover(binary(), signature, recovery_id) ::
          {:ok, ExthCrypto.Key.public_key()} | {:error, String.t()}
  def recover(digest, signature, recovery_id) do
    case :libsecp256k1.ecdsa_recover_compact(digest, signature, :uncompressed, recovery_id) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Combines a signature (64 bytes) with the recovery id. 
  """
  @spec compact_format(signature(), recovery_id()) :: compact_signature()
  def compact_format(signature, recovery_id) do
    signature <> :binary.encode_unsigned(recovery_id)
  end

  @doc """
  Separates a compact signature (64 bytes + recovery id) into its separate components.
  """
  @spec split_compact_format(compact_signature()) :: {signature(), recovery_id()}
  def split_compact_format(compact_signature) do
    <<signature::binary-size(@signature_length), recovery_id::binary-size(1)>> = compact_signature

    {signature, :binary.decode_unsigned(recovery_id)}
  end
end
