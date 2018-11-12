defmodule ExWire.Handshake.Struct.AckRespV4 do
  @moduledoc """
  Simple struct to wrap an auth response.

  The RLPx v4 handshake ack is defined in EIP-8.
  """

  alias ExthCrypto.Key

  defstruct [
    :recipient_ephemeral_public_key,
    :recipient_nonce,
    :recipient_version
  ]

  @type t :: %__MODULE__{
          recipient_ephemeral_public_key: Key.public_key(),
          recipient_nonce: binary(),
          recipient_version: integer()
        }

  @spec serialize(t) :: ExRLP.t()
  def serialize(ack_resp) do
    [
      ack_resp.recipient_ephemeral_public_key,
      ack_resp.recipient_nonce,
      ack_resp.recipient_version |> :binary.encode_unsigned()
    ]
  end

  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [recipient_ephemeral_public_key | rlp_tail] = rlp
    [recipient_nonce | rlp_tail] = rlp_tail
    [recipient_version | _tl] = rlp_tail

    %__MODULE__{
      recipient_ephemeral_public_key: recipient_ephemeral_public_key,
      recipient_nonce: recipient_nonce,
      recipient_version:
        if(
          is_binary(recipient_version),
          do: :binary.decode_unsigned(recipient_version),
          else: recipient_version
        )
    }
  end
end
