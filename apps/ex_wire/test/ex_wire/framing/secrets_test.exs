defmodule ExWire.Framing.SecretsTest do
  use ExUnit.Case, async: true
  doctest ExWire.Framing.Secrets

  alias ExWire.Framing.Secrets
  alias ExWire.Handshake
  alias ExthCrypto.ECIES.ECDH

  setup do
    creds = %{
      my_ephemeral_key_pair: new_ephemeral_key_pair(),
      remote_ephemeral_key_pair: new_ephemeral_key_pair(),
      my_nonce: new_nonce(),
      remote_nonce: new_nonce()
    }

    {:ok, %{credentials: creds}}
  end

  describe "derive_secrets/7" do
    test "generates token to resume connection in the future", %{credentials: creds} do
      %{
        my_ephemeral_key_pair: {_, my_eph_private_key},
        remote_ephemeral_key_pair: {remote_eph_public_key, _},
        my_nonce: my_nonce,
        remote_nonce: remote_nonce
      } = creds

      secrets =
        Secrets.derive_secrets(
          true,
          my_eph_private_key,
          remote_eph_public_key,
          remote_nonce,
          my_nonce,
          "auth data",
          "ack data"
        )

      assert %Secrets{} = secrets
      assert is_binary(secrets.token)
    end

    test "generates the mac encoder and mac secret", %{credentials: creds} do
      %{
        my_ephemeral_key_pair: {_, my_eph_private_key},
        remote_ephemeral_key_pair: {remote_eph_public_key, _},
        my_nonce: my_nonce,
        remote_nonce: remote_nonce
      } = creds

      secrets =
        Secrets.derive_secrets(
          true,
          my_eph_private_key,
          remote_eph_public_key,
          remote_nonce,
          my_nonce,
          "auth data",
          "ack data"
        )

      assert is_binary(secrets.mac_secret)
      assert {ExthCrypto.AES, 32, :ecb} = secrets.mac_encoder
    end

    test "calculates the egress and ingress mac", %{credentials: creds} do
      %{
        my_ephemeral_key_pair: {_, my_eph_private_key},
        remote_ephemeral_key_pair: {remote_eph_public_key, _},
        my_nonce: my_nonce,
        remote_nonce: remote_nonce
      } = creds

      secrets =
        Secrets.derive_secrets(
          true,
          my_eph_private_key,
          remote_eph_public_key,
          remote_nonce,
          my_nonce,
          "auth data",
          "ack data"
        )

      assert {:kec, {:sha3_256, egress_mac_data}} = secrets.egress_mac
      assert {:kec, {:sha3_256, ingress_mac_data}} = secrets.ingress_mac
      assert is_binary(egress_mac_data)
      assert is_binary(ingress_mac_data)
    end

    test "generates the encoder and decoder streams", %{credentials: creds} do
      %{
        my_ephemeral_key_pair: {_, my_eph_private_key},
        remote_ephemeral_key_pair: {remote_eph_public_key, _},
        my_nonce: my_nonce,
        remote_nonce: remote_nonce
      } = creds

      secrets =
        Secrets.derive_secrets(
          true,
          my_eph_private_key,
          remote_eph_public_key,
          remote_nonce,
          my_nonce,
          "auth data",
          "ack data"
        )

      assert {:aes_ctr, encoder_stream} = secrets.encoder_stream
      assert is_reference(encoder_stream)
      assert {:aes_ctr, decoder_stream} = secrets.decoder_stream
      assert is_reference(decoder_stream)
    end
  end

  def new_ephemeral_key_pair do
    ECDH.new_ecdh_keypair()
  end

  def new_nonce do
    Handshake.new_nonce()
  end
end
