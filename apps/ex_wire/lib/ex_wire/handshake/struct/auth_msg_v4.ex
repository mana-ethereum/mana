defmodule ExWire.Handshake.Struct.AuthMsgV4 do
  @moduledoc """
  Simple struct to wrap an auth msg.

  The RLPx v4 handshake auth is defined in EIP-8.
  """

  alias ExthCrypto.ECIES.ECDH

  defstruct [
    :signature,
    :remote_public_key,
    :remote_nonce,
    :remote_version,
    :remote_ephemeral_public_key
  ]

  @type t :: %__MODULE__{
    signature: ExthCrypto.signature,
    remote_public_key: ExthCrypto.Key.public_key,
    remote_nonce: binary(),
    remote_version: integer(),
    remote_ephemeral_public_key: ExthCrypto.Key.public_key,
  }

  @spec serialize(t) :: ExRLP.t
  def serialize(auth_msg) do
    [
      auth_msg.signature,
      auth_msg.remote_public_key |> ExthCrypto.Key.der_to_raw,
      auth_msg.remote_nonce,
      auth_msg.remote_version |> :binary.encode_unsigned
    ]
  end

  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      signature |
      [remote_public_key |
      [remote_nonce |
      [remote_version |
      _tl
    ]]]] = rlp

    %__MODULE__{
      signature: signature,
      remote_public_key: remote_public_key |> ExthCrypto.Key.raw_to_der,
      remote_nonce: remote_nonce,
      remote_version: (if is_binary(remote_version), do: :binary.decode_unsigned(remote_version), else: remote_version),
    }
  end

  @doc """
  Sets the remote ephemeral public key for a given auth msg, based on our secret
  and the keys passed from remote.

  # TODO: Test
  # TODO: Multiple possible values and no recovery key?
  """
  @spec set_remote_ephemeral_public_key(t, ExthCrypto.Key.private_key) :: t
  def set_remote_ephemeral_public_key(auth_msg, my_static_private_key) do
    shared_secret = ECDH.generate_shared_secret(my_static_private_key, auth_msg.remote_public_key)
    shared_secret_xor_nonce = :crypto.exor(shared_secret, auth_msg.remote_nonce)

    {:ok, remote_ephemeral_public_key} = ExthCrypto.Signature.recover(shared_secret_xor_nonce, auth_msg.signature, 0)

    %{auth_msg | remote_ephemeral_public_key: remote_ephemeral_public_key}
  end

end