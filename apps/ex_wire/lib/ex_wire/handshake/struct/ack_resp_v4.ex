defmodule ExWire.Handshake.Struct.AckRespV4 do
  @moduledoc """
  Simple struct to wrap an auth response.

  The RLPx v4 handshake ack is defined in EIP-8.
  """

  defstruct [
    :remote_ephemeral_public_key,
    :remote_nonce,
    :remote_version
  ]

  @type t :: %__MODULE__{
    remote_ephemeral_public_key: ExthCrypto.Key.public_key,
    remote_nonce: binary(),
    remote_version: integer(),
  }

  @spec serialize(t) :: ExRLP.t
  def serialize(auth_resp) do
    [
      auth_resp.remote_ephemeral_public_key,
      auth_resp.remote_nonce,
      auth_resp.remote_version |> :binary.encode_unsigned,
    ]
  end

  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      remote_ephemeral_public_key |
      [remote_nonce |
      [remote_version |
      _tl
    ]]] = rlp

    %__MODULE__{
      remote_ephemeral_public_key: remote_ephemeral_public_key,
      remote_nonce: remote_nonce,
      remote_version: (if is_binary(remote_version), do: :binary.decode_unsigned(remote_version), else: remote_version),
    }
  end

end