defmodule ExthCrypto.SignatureTest do
  use ExUnit.Case
  doctest ExthCrypto.Signature

  alias ExthCrypto.Signature
  alias ExthCrypto.Test

  describe "recover/3" do
    test "recovers correct public key" do
      private_key = Test.private_key(:key_a)
      public_key = Signature.get_public_key(private_key)
      message = "crypto alchemist"

      {signature, _r, _s, recovery_id} = Signature.sign_digest(message, private_key)
      recovered_public_key = Signature.recover(message, signature, recovery_id)

      assert recovered_public_key == public_key
    end
  end

  describe "compact_format/2" do
    test "returns a compacted signature (signature + recovery id)" do
      private_key = Test.private_key()
      message = "crypto alchemist"
      {signature, _r, _s, recovery_id} = Signature.sign_digest(message, private_key)

      compacted_signature = Signature.compact_format(signature, recovery_id)

      assert compacted_signature == signature <> :binary.encode_unsigned(recovery_id)
    end
  end

  describe "split_compact_format/1" do
    test "splits a compacted signature into the ECDSA signature and the recovery id" do
      private_key = Test.private_key()
      message = "crypto alchemist"
      {signature, _r, _s, recovery_id} = Signature.sign_digest(message, private_key)

      compacted_signature = Signature.compact_format(signature, recovery_id)

      assert {^signature, ^recovery_id} = Signature.split_compact_format(compacted_signature)
    end
  end
end
