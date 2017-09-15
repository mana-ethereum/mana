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

      iex> ExWire.Crypto.hash_matches("hi mom", <<51, 222, 224, 106, 155, 178, 233, 69, 38, 74, 183, 156, 110, 148, 129, 190, 246, 136, 166, 124, 116, 83, 123, 115, 172, 234, 183, 6, 88, 13, 110, 73>>)
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

      iex> ExWire.Crypto.assert_hash("hi mom", <<51, 222, 224, 106, 155, 178, 233, 69, 38, 74, 183, 156, 110, 148, 129, 190, 246, 136, 166, 124, 116, 83, 123, 115, 172, 234, 183, 6, 88, 13, 110, 73>>)
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
      <<51, 222, 224, 106, 155, 178, 233, 69, 38, 74, 183, 156, 110, 148,
             129, 190, 246, 136, 166, 124, 116, 83, 123, 115, 172, 234, 183, 6,
             88, 13, 110, 73>>

      iex> ExWire.Crypto.hash("hi dad")
      <<39, 50, 84, 152, 234, 20, 84, 210, 84, 196, 254, 160, 106, 252, 88,
             130, 210, 73, 57, 253, 245, 34, 91, 77, 120, 21, 141, 235, 231,
             215, 116, 164>>

      iex> ExWire.Crypto.hash("")
      <<167, 255, 198, 248, 191, 30, 215, 102, 81, 193, 71, 86, 160, 97,
             214, 98, 245, 128, 255, 77, 228, 59, 73, 250, 130, 216, 10, 75,
             128, 248, 67, 74>>
  """
  @spec hash(binary()) :: hash
  def hash(data) do
    :keccakf1600.sha3_256(data)
  end

  @doc """
  Given a `message`, `signature` and `recovery_id`, returns
  the public key used to generate the signature.

  ## Examples

      iex> signature = <<111, 189, 0, 183, 128, 171, 19, 7, 212, 56, 115, 79, 164, 209, 105, 29, 222, 109, 71, 236, 251, 169, 253, 95, 163, 139, 132, 147, 238, 77, 174, 199, 49, 40, 227, 227, 227, 30, 193, 141, 74, 254, 242, 162, 64, 85, 61, 7, 4, 186, 25, 205, 69, 194, 132, 0, 45, 194, 182, 236, 62, 208, 164, 96>>
      iex> ExWire.Crypto.recover_public_key("hi mom", signature, 0)
      <<4, 14, 171, 190, 251, 105, 241, 143, 202, 92, 170, 215, 184, 77, 2, 207, 17,
        8, 109, 230, 202, 206, 155, 170, 48, 182, 75, 0, 152, 82, 131, 31, 167, 42,
        61, 89, 82, 107, 179, 233, 35, 170, 76, 27, 55, 82, 67, 224, 80, 90, 135, 141,
        113, 73, 167, 0, 244, 141, 71, 113, 56, 108, 190, 103, 115>>
  """
  @spec recover_public_key(binary(), signature, recovery_id) :: public_key
  def recover_public_key(message, signature, recovery_id) do
    {:ok, public_key} = :libsecp256k1.ecdsa_recover_compact(
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

      iex> ExWire.Crypto.sign("hi mom", <<1::256>>)
      {:ok,
       <<111, 189, 0, 183, 128, 171, 19, 7, 212, 56, 115, 79, 164, 209, 105, 29, 222,
         109, 71, 236, 251, 169, 253, 95, 163, 139, 132, 147, 238, 77, 174, 199, 49,
         40, 227, 227, 227, 30, 193, 141, 74, 254, 242, 162, 64, 85, 61, 7, 4, 186,
         25, 205, 69, 194, 132, 0, 45, 194, 182, 236, 62, 208, 164, 96>>, 0}
  """
  @spec sign(binary(), private_key) :: {:ok, signature, recovery_id} | {:error, String.t}
  def sign(message, private_key) do
    case :libsecp256k1.ecdsa_sign_compact(message, private_key, :default, <<>>) do
      {:ok, signature, recovery_id} -> {:ok, signature, recovery_id}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

end