defmodule ExWire.Handshake.Struct.AuthMsgV4Test do
  use ExUnit.Case, async: true
  doctest ExWire.Handshake.Struct.AuthMsgV4

  alias ExWire.Handshake
  alias ExWire.Handshake.Struct.AuthMsgV4
  alias ExthCrypto.ECIES.ECDH

  setup do
    keys = %{
      initiator_static_public_key: ExthCrypto.Test.public_key(:key_a),
      initiator_static_private_key: ExthCrypto.Test.private_key(:key_a),
      recipient_static_public_key: ExthCrypto.Test.public_key(:key_b),
      recipient_static_private_key: ExthCrypto.Test.private_key(:key_b)
    }

    {:ok, %{keys: keys}}
  end

  describe "set_remote_ephemeral_public_key/2" do
    test "recovers and sets initiators ephemeral public key from shared secret", %{keys: keys} do
      initiator_nonce = Handshake.new_nonce()
      {initiator_ephemeral_public_key, initiator_ephemeral_private_key} = ECDH.new_ecdh_keypair()

      {signature, recovery_id} =
        generate_signature_and_recovery_id(initiator_ephemeral_private_key, initiator_nonce, keys)

      auth_msg = build_auth_msg(signature, recovery_id, initiator_nonce, keys)

      new_auth_msg =
        AuthMsgV4.set_remote_ephemeral_public_key(auth_msg, keys.recipient_static_private_key)

      assert new_auth_msg.remote_ephemeral_public_key == initiator_ephemeral_public_key
    end
  end

  def build_auth_msg(signature, recovery_id, initiator_nonce, keys) do
    %AuthMsgV4{
      signature: signature <> :binary.encode_unsigned(recovery_id),
      remote_public_key: keys.initiator_static_public_key,
      remote_nonce: initiator_nonce
    }
  end

  def generate_signature_and_recovery_id(initiator_ephemeral_private_key, initiator_nonce, keys) do
    {signature, _r, _s, recovery_id} =
      keys.initiator_static_private_key
      |> ECDH.generate_shared_secret(keys.recipient_static_public_key)
      |> ExthCrypto.Math.xor(initiator_nonce)
      |> ExthCrypto.Signature.sign_digest(initiator_ephemeral_private_key)

    {signature, recovery_id}
  end
end
