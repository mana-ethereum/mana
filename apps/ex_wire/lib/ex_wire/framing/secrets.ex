defmodule ExWire.Framing.Secrets do
  @moduledoc """
  Secrets are used to both encrypt and authenticate incoming
  and outgoing peer to peer messages.
  """

  alias ExthCrypto.AES
  alias ExthCrypto.MAC
  alias ExthCrypto.Hash.Keccak

  @type t :: %__MODULE__{
    egress_mac: MAC.mac_inst,
    ingress_mac: MAC.mac_inst,
    mac_encoder: ExthCrypto.Cipher.cipher,
    mac_secret: ExthCrypto.Key.symmetric_key,
    encoder_stream: ExthCrypto.Cipher.stream,
    decoder_stream: ExthCrypto.Cipher.stream,
    token: binary()
  }

  defstruct [
    :egress_mac,
    :ingress_mac,
    :mac_encoder,
    :mac_secret,
    :encoder_stream,
    :decoder_stream,
    :token
  ]

  @spec new(MAC.mac_inst, MAC.mac_inst, ExthCrypto.Key.symmetric_key, ExthCrypto.Key.symmetric_key, binary()) :: t
  def new(egress_mac, ingress_mac, mac_secret, symmetric_key, token) do
    # initialize AES stream with empty init_vector
    encoder_stream = AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)
    decoder_stream = AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)
    mac_encoder = {AES, AES.block_size, :ecb}

    %__MODULE__{
      egress_mac: egress_mac,
      ingress_mac: ingress_mac,
      mac_encoder: mac_encoder,
      mac_secret: mac_secret,
      encoder_stream: encoder_stream,
      decoder_stream: decoder_stream,
      token: token
    }
  end

  @doc """
  After a handshake has been completed (i.e. auth and ack have been exchanged),
  we're ready to derive the secrets to be used to encrypt frames. This function
  performs the required computation.

  # TODO: Add examplex
  # TODO: Clean up API interface
  """
  @spec derive_secrets(ExthCrypto.Key.private_key, ExthCrypto.Key.public_key, binary(), binary(), binary(), binary()) :: t
  def derive_secrets(my_ephemeral_private_key, remote_ephemeral_public_key, remote_nonce, my_nonce, auth_data, ack_data) do
    remote_ephemeral_public_key_raw = remote_ephemeral_public_key |> ExthCrypto.Key.raw_to_der

    ephemeral_shared_secret = ExthCrypto.ECIES.ECDH.generate_shared_secret(my_ephemeral_private_key, remote_ephemeral_public_key_raw)

    # TODO: Nonces will need to be reversed come winter
    shared_secret = Keccak.kec(ephemeral_shared_secret <> Keccak.kec(remote_nonce <> my_nonce))

    # `token` can be used to resume a connection with a minimal handshake
    token = Keccak.kec(shared_secret)

    aes_secret = Keccak.kec(ephemeral_shared_secret <> shared_secret)
    mac_secret = Keccak.kec(ephemeral_shared_secret <> aes_secret)

    mac_1 =
      MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, remote_nonce))
      |> MAC.update(auth_data)

    mac_2 = MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, my_nonce))
      |> MAC.update(ack_data)

    # TODO: Reverse this based on if we're sender or receiver
    egress_mac = mac_1
    ingress_mac = mac_2

    __MODULE__.new(
      egress_mac,
      ingress_mac,
      mac_secret,
      aes_secret,
      token
    )
  end
end