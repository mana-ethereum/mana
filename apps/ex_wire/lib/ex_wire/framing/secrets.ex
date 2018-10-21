defmodule ExWire.Framing.Secrets do
  @moduledoc """
  Secrets are used to both encrypt and authenticate incoming
  and outgoing peer to peer messages.
  """

  alias ExthCrypto.{AES, MAC}
  alias ExthCrypto.ECIES.ECDH
  alias ExthCrypto.Hash.Keccak
  alias ExWire.Handshake

  @type t :: %__MODULE__{
          egress_mac: MAC.mac_inst(),
          ingress_mac: MAC.mac_inst(),
          mac_encoder: ExthCrypto.Cipher.cipher(),
          mac_secret: ExthCrypto.Key.symmetric_key(),
          encoder_stream: ExthCrypto.Cipher.stream(),
          decoder_stream: ExthCrypto.Cipher.stream(),
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

  @spec new(
          MAC.mac_inst(),
          MAC.mac_inst(),
          ExthCrypto.Key.symmetric_key(),
          ExthCrypto.Key.symmetric_key(),
          binary()
        ) :: t
  def new(egress_mac, ingress_mac, mac_secret, symmetric_key, token) do
    # initialize AES stream with empty init_vector
    encoder_stream = AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)
    decoder_stream = AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)
    mac_encoder = {AES, AES.block_size(), :ecb}

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
  performs the required computation. The token created as part of these secrets
  can be used to resume a connection with a minimal handshake.

  From RLPx documentation (https://github.com/ethereum/devp2p/blob/master/rlpx.md),

  ```
  ephemeral-shared-secret = ecdh.agree(ephemeral-privkey, remote-ephemeral-pubk)
  shared-secret = sha3(ephemeral-shared-secret || sha3(nonce || initiator-nonce))
  token = sha3(shared-secret)
  aes-secret = sha3(ephemeral-shared-secret || shared-secret)
  # destroy shared-secret
  mac-secret = sha3(ephemeral-shared-secret || aes-secret)
  # destroy ephemeral-shared-secret

  Initiator:
  egress-mac = sha3.update(mac-secret ^ recipient-nonce || auth-sent-init)
  # destroy nonce
  ingress-mac = sha3.update(mac-secret ^ initiator-nonce || auth-recvd-ack)
  # destroy remote-nonce

  Recipient:
  egress-mac = sha3.update(mac-secret ^ initiator-nonce || auth-sent-ack)
  # destroy nonce
  ingress-mac = sha3.update(mac-secret ^ recipient-nonce || auth-recvd-init)
  # destroy remote-nonce
  ```
  """

  def derive_secrets(handshake = %Handshake{}) do
    {_public, private_key} = handshake.random_key_pair

    ephemeral_shared_secret =
      ECDH.generate_shared_secret(private_key, handshake.remote_random_pub)

    shared_secret =
      Keccak.kec(
        ephemeral_shared_secret <> Keccak.kec(handshake.resp_nonce <> handshake.init_nonce)
      )

    token = Keccak.kec(shared_secret)

    aes_secret = Keccak.kec(ephemeral_shared_secret <> shared_secret)
    mac_secret = Keccak.kec(ephemeral_shared_secret <> aes_secret)

    {egress_mac, ingress_mac} = derive_ingress_egress(handshake, mac_secret)

    new(egress_mac, ingress_mac, mac_secret, aes_secret, token)
  end

  def derive_ingress_egress(handshake = %Handshake{initiator: true}, mac_secret) do
    egress_mac =
      MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, handshake.resp_nonce))
      |> MAC.update(handshake.encoded_auth_msg)

    ingress_mac =
      MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, handshake.init_nonce))
      |> MAC.update(handshake.encoded_ack_resp)

    {egress_mac, ingress_mac}
  end

  def derive_ingress_egress(handshake = %Handshake{initiator: false}, mac_secret) do
    egress_mac =
      MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, handshake.init_nonce))
      |> MAC.update(handshake.encoded_ack_resp)

    ingress_mac =
      MAC.init(:kec)
      |> MAC.update(ExthCrypto.Math.xor(mac_secret, handshake.resp_nonce))
      |> MAC.update(handshake.encoded_auth_msg)

    {egress_mac, ingress_mac}
  end
end
