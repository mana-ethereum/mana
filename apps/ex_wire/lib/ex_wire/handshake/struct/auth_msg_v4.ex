defmodule ExWire.Handshake.Struct.AuthMsgV4 do
  @moduledoc """
  Simple struct to wrap an auth msg.

  The RLPx v4 handshake auth is defined in EIP-8.
  """

  alias ExthCrypto.ECIES.ECDH

  defstruct [
    :signature,
    :initiator_public_key,
    :initiator_nonce,
    :initiator_version,
    :initiator_ephemeral_public_key
  ]

  @type t :: %__MODULE__{
          signature: ExthCrypto.Signature.compact_signature(),
          initiator_public_key: ExthCrypto.Key.public_key_der(),
          initiator_nonce: binary(),
          initiator_version: integer(),
          initiator_ephemeral_public_key: ExthCrypto.Key.public_key() | nil
        }

  @spec serialize(t()) :: ExRLP.t()
  def serialize(auth_msg) do
    [
      auth_msg.signature,
      ExthCrypto.Key.der_to_raw(auth_msg.initiator_public_key),
      auth_msg.initiator_nonce,
      :binary.encode_unsigned(auth_msg.initiator_version)
    ]
  end

  @spec deserialize(nonempty_maybe_improper_list()) :: t()
  def deserialize(rlp) do
    [signature | rlp_tail] = rlp
    [initiator_public_key | rlp_tail] = rlp_tail
    [initiator_nonce | rlp_tail] = rlp_tail
    [initiator_version | _tl] = rlp_tail

    %__MODULE__{
      signature: signature,
      initiator_public_key: initiator_public_key |> ExthCrypto.Key.raw_to_der(),
      initiator_nonce: initiator_nonce,
      initiator_version:
        if(
          is_binary(initiator_version),
          do: :binary.decode_unsigned(initiator_version),
          else: initiator_version
        )
    }
  end

  @doc """
  Sets the initiator ephemeral public key for a given auth msg, based on our secret
  and the keys passed from initiator.
  """
  @spec set_initiator_ephemeral_public_key(t(), ExthCrypto.Key.private_key()) :: t()
  def set_initiator_ephemeral_public_key(auth_msg = %__MODULE__{}, my_static_private_key) do
    shared_secret_xor_nonce =
      my_static_private_key
      |> ECDH.generate_shared_secret(auth_msg.initiator_public_key)
      |> ExthCrypto.Math.xor(auth_msg.initiator_nonce)

    {signature, recovery_id} = ExthCrypto.Signature.split_compact_format(auth_msg.signature)

    {:ok, initiator_ephemeral_public_key} =
      ExthCrypto.Signature.recover(shared_secret_xor_nonce, signature, recovery_id)

    %{auth_msg | initiator_ephemeral_public_key: initiator_ephemeral_public_key}
  end
end
