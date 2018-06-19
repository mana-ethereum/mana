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

    {remote_eph_public_key, _} = new_ephemeral_key_pair()

    handshake = %Handshake{
      initiator: true,
      init_nonce: new_nonce(),
      resp_nonce: new_nonce(),
      random_key_pair: new_ephemeral_key_pair(),
      remote_random_pub: remote_eph_public_key,
      encoded_auth_msg: "auth data",
      encoded_ack_resp: "ack resp"
    }

    {:ok, %{credentials: creds, handshake: handshake}}
  end

  describe "derive_secrets/7" do
    test "generates token to resume connection in the future", %{handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      assert %Secrets{} = secrets
      assert is_binary(secrets.token)
    end

    test "generates the mac encoder and mac secret", %{handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      assert is_binary(secrets.mac_secret)
      assert {ExthCrypto.AES, 32, :ecb} = secrets.mac_encoder
    end

    test "calculates the egress and ingress mac", %{handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      assert {:kec, {:sha3_256, egress_mac_data}} = secrets.egress_mac
      assert {:kec, {:sha3_256, ingress_mac_data}} = secrets.ingress_mac
      assert is_binary(egress_mac_data)
      assert is_binary(ingress_mac_data)
    end

    test "generates the encoder and decoder streams", %{handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      assert {:aes_ctr, encoder_stream} = secrets.encoder_stream
      assert is_reference(encoder_stream)
      assert {:aes_ctr, decoder_stream} = secrets.decoder_stream
      assert is_reference(decoder_stream)
    end
  end

  describe "EIP-8 tests" do
    # These tests come from https://github.com/ethereum/EIPs/blob/master/EIPS/eip-8.md#rlpx-handshake

    setup do
      creds = eip8_credentials()

      recipient_handshake = %Handshake{
        initiator: false,
        init_nonce: creds.nonce_a,
        resp_nonce: creds.nonce_b,
        random_key_pair: {creds.ephemeral_public_key_b, creds.ephemeral_key_b},
        remote_random_pub: creds.ephemeral_public_key_a,
        encoded_auth_msg: creds.auth_2,
        encoded_ack_resp: creds.ack_2
      }

      initiator_handshake = %Handshake{
        initiator: true,
        init_nonce: creds.nonce_a,
        resp_nonce: creds.nonce_b,
        random_key_pair: {creds.ephemeral_public_key_a, creds.ephemeral_key_a},
        remote_random_pub: creds.ephemeral_public_key_b,
        encoded_auth_msg: creds.auth_2,
        encoded_ack_resp: creds.ack_2
      }

      {:ok, %{initiator_handshake: initiator_handshake, recipient_handshake: recipient_handshake}}
    end

    test "Recipient generates mac-secret correctly", %{recipient_handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      assert secrets.mac_secret ==
               bin_format("2ea74ec5dae199227dff1af715362700e989d889d7a493cb0639691efb8e5f98")
    end

    test "generates correct ingress-mac", %{recipient_handshake: handshake} do
      secrets = Secrets.derive_secrets(handshake)

      updated_mac =
        secrets.ingress_mac
        |> ExthCrypto.MAC.update("foo")
        |> ExthCrypto.MAC.final()

      assert updated_mac ==
               bin_format("0c7ec6340062cc46f5e9f1e3cf86f8c8c403c5a0964f5df0ebd34a75ddc86db5")
    end

    test "initiator's egress mac is equal to recipients ingress mac", %{
      initiator_handshake: handshake1,
      recipient_handshake: handshake2
    } do
      init_secrets = Secrets.derive_secrets(handshake1)

      recipient_secrets = Secrets.derive_secrets(handshake2)

      assert recipient_secrets.ingress_mac == init_secrets.egress_mac
    end
  end

  defp eip8_credentials do
    eip8_creds =
      %{
        static_key_a: "49a7b37aa6f6645917e7b807e9d1c00d4fa71f18343b0d4122a4d2df64dd6fee",
        static_key_b: "b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291",
        ephemeral_key_a: "869d6ecf5211f1cc60418a13b9d870b22959d0c16f02bec714c960dd2298a32d",
        ephemeral_key_b: "e238eb8e04fee6511ab04c6dd3c89ce097b11f25d584863ac2b6d5b35b1847e4",
        nonce_a: "7e968bba13b6c50e2c4cd7f241cc0d64d1ac25c7f5952df231ac6a2bda8ee5d6",
        nonce_b: "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd",
        auth_2: auth_2(),
        ack_2: ack_2()
      }
      |> Enum.map(fn {k, v} -> {k, bin_format(v)} end)
      |> Enum.into(%{})

    public_keys = %{
      ephemeral_public_key_a: public_key(eip8_creds.ephemeral_key_a),
      ephemeral_public_key_b: public_key(eip8_creds.ephemeral_key_b)
    }

    Map.merge(eip8_creds, public_keys)
  end

  defp auth_2 do
    """
    01b304ab7578555167be8154d5cc456f567d5ba302662433674222360f08d5f1534499d3678b513b
    0fca474f3a514b18e75683032eb63fccb16c156dc6eb2c0b1593f0d84ac74f6e475f1b8d56116b84
    9634a8c458705bf83a626ea0384d4d7341aae591fae42ce6bd5c850bfe0b999a694a49bbbaf3ef6c
    da61110601d3b4c02ab6c30437257a6e0117792631a4b47c1d52fc0f8f89caadeb7d02770bf999cc
    147d2df3b62e1ffb2c9d8c125a3984865356266bca11ce7d3a688663a51d82defaa8aad69da39ab6
    d5470e81ec5f2a7a47fb865ff7cca21516f9299a07b1bc63ba56c7a1a892112841ca44b6e0034dee
    70c9adabc15d76a54f443593fafdc3b27af8059703f88928e199cb122362a4b35f62386da7caad09
    c001edaeb5f8a06d2b26fb6cb93c52a9fca51853b68193916982358fe1e5369e249875bb8d0d0ec3
    6f917bc5e1eafd5896d46bd61ff23f1a863a8a8dcd54c7b109b771c8e61ec9c8908c733c0263440e
    2aa067241aaa433f0bb053c7b31a838504b148f570c0ad62837129e547678c5190341e4f1693956c
    3bf7678318e2d5b5340c9e488eefea198576344afbdf66db5f51204a6961a63ce072c8926c
    """
    |> String.replace("\n", "")
  end

  defp ack_2 do
    """
    01ea0451958701280a56482929d3b0757da8f7fbe5286784beead59d95089c217c9b917788989470
    b0e330cc6e4fb383c0340ed85fab836ec9fb8a49672712aeabbdfd1e837c1ff4cace34311cd7f4de
    05d59279e3524ab26ef753a0095637ac88f2b499b9914b5f64e143eae548a1066e14cd2f4bd7f814
    c4652f11b254f8a2d0191e2f5546fae6055694aed14d906df79ad3b407d94692694e259191cde171
    ad542fc588fa2b7333313d82a9f887332f1dfc36cea03f831cb9a23fea05b33deb999e85489e645f
    6aab1872475d488d7bd6c7c120caf28dbfc5d6833888155ed69d34dbdc39c1f299be1057810f34fb
    e754d021bfca14dc989753d61c413d261934e1a9c67ee060a25eefb54e81a4d14baff922180c395d
    3f998d70f46f6b58306f969627ae364497e73fc27f6d17ae45a413d322cb8814276be6ddd13b885b
    201b943213656cde498fa0e9ddc8e0b8f8a53824fbd82254f3e2c17e8eaea009c38b4aa0a3f306e8
    797db43c25d68e86f262e564086f59a2fc60511c42abfb3057c247a8a8fe4fb3ccbadde17514b7ac
    8000cdb6a912778426260c47f38919a91f25f4b5ffb455d6aaaf150f7e5529c100ce62d6d92826a7
    1778d809bdf60232ae21ce8a437eca8223f45ac37f6487452ce626f549b3b5fdee26afd2072e4bc7
    5833c2464c805246155289f4
    """
    |> String.replace("\n", "")
  end

  defp bin_format(hex) do
    ExWire.Crypto.hex_to_bin(hex)
  end

  defp public_key(private) do
    {:ok, pub} = ExthCrypto.Signature.get_public_key(private)
    pub
  end

  defp new_ephemeral_key_pair do
    ECDH.new_ecdh_keypair()
  end

  defp new_nonce do
    Handshake.new_nonce()
  end
end
