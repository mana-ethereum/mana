defmodule ExWire.Crypto do
  @moduledoc """
  Helper functions for cryptographic functions of RLPx.
  """

  alias ExthCrypto.{Signature, Key, Math}
  alias ExthCrypto.Hash.Keccak

  @type hash :: binary()
  @type signature :: binary()
  @type recovery_id :: integer()

  defmodule HashMismatch do
    defexception [:message]
  end

  defdelegate der_to_raw(der_bin), to: Key
  defdelegate raw_to_der(bin), to: Key
  defdelegate hex_to_bin(hex_bin), to: Math
  defdelegate bin_to_hex(bin), to: Math

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
  @spec node_id(Key.private_key()) :: {:ok, ExWire.node_id()} | {:error, String.t()}
  def node_id(private_key) do
    case Signature.get_public_key(private_key) do
      {:ok, <<public_key::binary()>>} -> {:ok, public_key |> Key.der_to_raw()}
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
    Keccak.kec(data)
  end

  @doc """
  Recovers a public key from a given signature for a given digest.

  ## Examples
      iex> message = <<240, 201, 132, 52, 176, 100, 77, 130, 118, 95, 128, 160, 58, 157, 88,
      ...>  6, 70, 100, 4, 170, 21, 252, 246, 14, 229, 171, 61, 176, 239, 240, 118, 204,
      ...>  61, 77, 7, 43, 205, 70, 112, 52, 27, 79, 131, 59, 132, 91, 3, 199, 199>>
      iex> signature = <<193, 30, 149, 122, 226, 192, 230, 158, 118, 204, 173, 80, 63,
      ...>   232, 67, 152, 216, 249, 89, 52, 162, 92, 233, 201, 177, 108, 63, 120, 152,
      ...>   134, 149, 220, 73, 198, 29, 93, 218, 123, 50, 70, 8, 202, 17, 171, 67, 245,
      ...>   70, 235, 163, 158, 201, 246, 223, 114, 168, 7, 7, 95, 9, 53, 165, 8, 177,
      ...>   13>>
      iex> ExWire.Crypto.recover_public_key(message, signature, 1)
      <<4, 89, 43, 26, 95, 28, 0, 213, 63, 213, 214, 141, 7, 112, 103, 70, 144, 161,
        213, 121, 174, 81, 195, 152, 74, 11, 239, 198, 197, 199, 108, 83, 254, 219,
        185, 91, 252, 107, 196, 30, 137, 64, 224, 60, 229, 20, 168, 35, 251, 75, 143,
        85, 130, 147, 90, 33, 104, 100, 96, 18, 220, 253, 58, 85, 207>>
  """
  @spec recover_public_key(binary(), binary(), integer()) :: integer()
  def recover_public_key(message, signature, recovery_id) do
    {:ok, public_key} = Signature.recover(message, signature, recovery_id)

    public_key
  end

  @spec node_id_from_public_key(binary()) :: binary()
  def node_id_from_public_key(public_key) do
    Key.der_to_raw(public_key)
  end
end
