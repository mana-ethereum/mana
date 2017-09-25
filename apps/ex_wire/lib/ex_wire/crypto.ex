defmodule ExWire.Crypto do
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
  Returns a node_id based on a given private key.

  ## Examples

      iex> ExWire.Crypto.node_id(<<1::256>>)
      {:ok, <<121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149,
              206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40, 217, 89,
              242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163,
              196, 101, 93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180,
              72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

      iex> ExWire.Crypto.node_id(<<1>>)
      {:error, "Private key size not 32 bytes"}
  """
  @spec node_id(private_key) :: {:ok, ExWire.node_id} | {:error, String.t}
  def node_id(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, <<_byte::8, public_key::binary()>>} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Validates whether a hash matches a given set of data
  via a SHA3 function, or returns `:invalid`.

  ## Examples

      iex> ExWire.Crypto.hash_matches("hi mom", <<228, 33, 19, 6, 43, 181, 255, 41, 190, 203, 202, 88, 58, 103, 207, 48, 227, 138, 243, 96, 69, 152, 95, 32, 48, 43, 200, 207, 79, 64, 252, 60>>)
      :valid

      iex> ExWire.Crypto.hash_matches("hi mom", <<3>>)
      :invalid
  """
  @spec hash_matches(binary(), hash) :: :valid | :invalid
  def hash_matches(data, check_hash) do
    if hash(data) == check_hash do
      :valid
    else
      :invalid
    end
  end

  @doc """
  Similar to `hash_matches/2`, except raises an error if there
  is an invalid hash.

  ## Examples

      iex> ExWire.Crypto.assert_hash("hi mom", <<228, 33, 19, 6, 43, 181, 255, 41, 190, 203, 202, 88, 58, 103, 207, 48, 227, 138, 243, 96, 69, 152, 95, 32, 48, 43, 200, 207, 79, 64, 252, 60>>)
      :ok

      iex> ExWire.Crypto.assert_hash("hi mom", <<3>>)
      ** (ExWire.Crypto.HashMismatch) Invalid hash
  """
  @spec assert_hash(binary(), hash) :: :ok
  def assert_hash(data, check_hash) do
    case hash_matches(data, check_hash) do
      :valid -> :ok
      :invalid -> raise HashMismatch, "Invalid hash"
    end
  end

  @doc """
  Returns the SHA3 hash of a given set of data.

  ## Examples

      iex> ExWire.Crypto.hash("hi mom")
      <<228, 33, 19, 6, 43, 181, 255, 41, 190, 203, 202, 88, 58, 103, 207,
             48, 227, 138, 243, 96, 69, 152, 95, 32, 48, 43, 200, 207, 79, 64,
             252, 60>>

      iex> ExWire.Crypto.hash("hi dad")
      <<239, 144, 71, 138, 41, 74, 120, 227, 61, 182, 176, 178, 193, 220,
             118, 58, 85, 199, 164, 53, 22, 64, 16, 14, 145, 25, 92, 250, 124,
             174, 44, 234>>

      iex> ExWire.Crypto.hash("")
      <<197, 210, 70, 1, 134, 247, 35, 60, 146, 126, 125, 178, 220, 199, 3,
             192, 229, 0, 182, 83, 202, 130, 39, 59, 123, 250, 216, 4, 93, 133,
             164, 112>>
  """
  @spec hash(binary()) :: hash
  def hash(data) do
    :keccakf1600.sha3_256(data)
  end

  @doc """
  Given a `message`, `signature` and `recovery_id`, returns
  the public key used to generate the signature.

  ## Examples

      iex> signature = <<99, 250, 55, 205, 19, 130, 162, 13, 36, 5, 43, 56, 228, 33, 106, 40, 191, 186, 82, 110, 80, 114, 235, 3, 47, 23, 113, 82, 97, 233, 154, 66, 124, 14, 92, 230, 187, 138, 47, 232, 236, 204, 103, 181, 60, 13, 22, 104, 69, 242, 94, 93, 227, 91, 182, 102, 145, 242, 186, 58, 190, 37, 39, 213>>
      iex> ExWire.Crypto.recover_public_key("hi mom", signature, 1)
      <<4, 14, 171, 190, 251, 105, 241, 143, 202, 92, 170, 215, 184, 77, 2, 207, 17,
        8, 109, 230, 202, 206, 155, 170, 48, 182, 75, 0, 152, 82, 131, 31, 167, 42,
        61, 89, 82, 107, 179, 233, 35, 170, 76, 27, 55, 82, 67, 224, 80, 90, 135, 141,
        113, 73, 167, 0, 244, 141, 71, 113, 56, 108, 190, 103, 115>>
  """
  @spec recover_public_key(binary(), signature, recovery_id) :: public_key
  def recover_public_key(message, signature, recovery_id) do
    {:ok, <<_byte::8, public_key::binary()>>} = :libsecp256k1.ecdsa_recover_compact(
      hash(message),
      signature,
      :uncompressed,
      recovery_id
    )

    public_key
  end

  @doc """
  Signs a given message with a private key.

  ## Examples

      iex> private_key = <<1::256>>
      iex> {:ok, <<_byte::8, public_key::binary()>>} = :libsecp256k1.ec_pubkey_create(private_key, :uncompressed)
      iex> {:ok, signature, _recovery_id} = ExWire.Crypto.sign(msg="hi mom", private_key) |> IO.inspect(limit: :infinity)
      iex> :libsecp256k1.ecdsa_verify(msg, signature |> IO.inspect, public_key |> IO.inspect)
      :ok

      iex> {:ok, signature, _recovery_id} = ExWire.Crypto.sign("hi mom", <<1::256>>)
      iex> :libsecp256k1.ecdsa_verify("hi mom", signature, <<2::256>>)
      {:error, 'ecdsa signature der parse error'}
  """
  @spec sign(binary(), private_key) :: {:ok, signature, recovery_id} | {:error, String.t}
  def sign(message, private_key) do
    case :libsecp256k1.ecdsa_sign_compact(message, private_key, :default, <<>>) do
      {:ok, signature, recovery_id} -> {:ok, signature, recovery_id}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

end