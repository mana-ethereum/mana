defmodule ExWire.CryptoTest do
  use ExUnit.Case, async: true
  doctest ExWire.Crypto

  test "recover public key from signature" do
    {:ok, signature, recovery_id} = ExWire.Crypto.sign("hi mom", <<1::256>>)
    public_key = ExWire.Crypto.recover_public_key("hi mom", signature, recovery_id)

    assert {:ok, public_key} == :libsecp256k1.ec_pubkey_create(<<1::256>>, :uncompressed)
  end

end