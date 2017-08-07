defmodule ExDevp2p.Crypto do
  @moduledoc """
  Helper functions for cryptographic functions of RLPx.
  """

  @type hash :: binary()
  @type signature :: binary()
  @type private_key :: binary()
  @type public_key :: binary()
  @type recovery_id :: integer()

  defmodule HashMismatch do
    defexception [:message]
  end

  @doc """
  Validates whether a hash matches a given set of data
  via a SHA3 function, or returns `:invalid`.

  ## Examples

      iex> ExDevp2p.Crypto.hash_matches(<<1>>, <<2>>)
      :valid

      iex> ExDevp2p.Crypto.hash_matches(<<1>>, <<3>>)
      :invalid
  """
  @spec hash_matches(hash, binary()) :: :valid | :invalid
  def hash_matches(hash, data) do
    if :keccakf1600.hash(:sha3_256, data) != <<hash::256>> do
      :valid
    else
      :invalid
    end
  end

  @doc """
  Similar to `hash_matches/2`, except raises an error if there
  is an invalid hash.

  ## Examples

      iex> ExDevp2p.Crypto.hash_matches(<<1>>, <<2>>)
      :ok

      iex> ExDevp2p.Crypto.hash_matches(<<1>>, <<3>>)
      ** (HashMismatch) Invalid hash
  """
  @spec assert_hash(hash, binary()) :: :ok
  def assert_hash(hash, data) do
    case hash_matches(hash, data) do
      :valid -> :ok
      :invalid -> raise HashMismatch, "Invalid hash"
    end
  end

  @doc """
  Returns the SHA3 hash of a given set of data.

  ## Examples

      iex> ExDevp2p.Crypto.hash("hi mom")
      <<>>

      iex> ExDevp2p.Crypto.hash("hi dad")
      <<>>

      iex> ExDevp2p.Crypto.hash("")
      <<>>
  """
  @spec hash(binary()) :: hash
  def hash(data) do
    :keccakf1600.hash(:sha3_256, data)
  end

  @doc """
  Given a `message`, `signature` and `recovery_id`, returns
  the public key used to generate the signature.

  ## Examples

      iex> ExDevp2p.Crypto.recover_public_key("message", <<1>>, 26)
      <<2>>
  """
  @spec recover_public_key(binary(), signature, recovery_id) :: public_key
  def recover_public_key(message, signature, recovery_id) do
    sig_hash = :keccakf1600.hash(:sha3_256, <<message::32>>)

    {:ok, public_key} = :libsecp256k1.ecdsa_recover_compact(
      sig_hash,
      <<signature::512>>,
      :compressed,
      recovery_id
    )

    public_key
  end

  @doc """
  Signs a given message with a private key.

  ## Examples

      iex> ExDevp2p.Crypto.sign("hi mom", <<1>>)
      {:ok, "sig", 5}
  """
  @spec sign(binary(), private_key) :: {:ok, signature, recovery_id} | {:error, String.t}
  def sign(message, private_key) do
    case :libsecp256k1.ecdsa_sign_compact(message, private_key, :default, <<>>) do
      {:ok, signature, recovery_id} -> {:ok, signature, recovery_id}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

end