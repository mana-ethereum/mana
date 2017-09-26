defmodule ExCrypto.Signature do
  @moduledoc """
  A variety of functions for calculating cryptographic signatures.

  Right now these all rely on the `libsecp256k1` library, and thus only
  performs signatures on this Elliptic Curve, but I don't see any reason
  why we couldn't switch to standard libraries if they provide similar
  functionality.
  """

  @type signature :: binary()
  @type r :: integer()
  @type s :: integer()
  @type recovery_id :: integer()

  @doc """
  Given a private key, returns a public key.

  ## Examples

      iex> ExCrypto.Signature.get_public_key(ExCrypto.Test.private_key)
      {:ok, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
             159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
             171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
             120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>}

      iex> ExCrypto.Signature.get_public_key(<<1>>)
      {:error, "Private key size not 32 bytes"}
  """
  @spec get_public_key(ExCrypto.private_key) :: {:ok, ExCrypto.public_key} | {:error, String.t}
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

      iex> {signature, _r, _s, _recovery_id} = ExCrypto.Signature.sign_digest("12345", ExCrypto.Test.private_key)
      iex> ExCrypto.Signature.verify("12345", signature, ExCrypto.Test.public_key)
      true
  """
  @spec sign_digest(binary(), ExCrypto.private_key) :: {signature, r, s, recovery_id}
  def sign_digest(digest, private_key) do
    {:ok, <<r::size(256), s::size(256)>>=signature, recovery_id} = :libsecp256k1.ecdsa_sign_compact(digest, private_key, :default, <<>>)

    sign_digest(digest, private_key)
  end

  @doc """
  Verifies a that a given signature for a given digest is valid against a public key.

  ## Examples

      iex> {signature, _r, _s, _recovery_id} = ExCrypto.Signature.sign_digest("12345", ExCrypto.Test.private_key(:key_a))
      iex> ExCrypto.Signature.verify("12345", signature, ExCrypto.Test.public_key(:key_a))
      true

      iex> {signature, _r, _s, _recovery_id} = ExCrypto.Signature.sign_digest("12345", ExCrypto.Test.private_key(:key_a))
      iex> ExCrypto.Signature.verify("12345", signature, ExCrypto.Test.public_key(:key_b))
      false
  """
  @spec verify(binary(), signature, ExCrypto.public_key) :: boolean()
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

      iex> {signature, _r, _s, _recovery_id} = ExCrypto.Signature.sign_digest("12345", ExCrypto.Test.private_key(:key_a))
      iex> ExCrypto.Signature.recover("12345", signature, 0)
      {:ok, <<4, 54, 241, 224, 126, 85, 135, 69, 213, 129, 115, 3, 41, 161, 217, 87, 215,
              159, 64, 17, 167, 128, 113, 172, 232, 46, 34, 145, 136, 72, 160, 207, 161,
              171, 255, 26, 163, 160, 158, 227, 196, 92, 62, 119, 84, 156, 99, 224, 155,
              120, 250, 153, 134, 180, 218, 177, 186, 200, 199, 106, 97, 103, 50, 215, 114>>}
  """
  @spec recover(binary(), signature, recovery_id) :: {:ok, ExCrypto.public_key} | {:error, String.t}
  def recover(digest, signature, recovery_id) do
    case :libsecp256k1.ecdsa_recover_compact(digest, signature, :uncompressed, recovery_id) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

end