defmodule ExDevp2p.Crypto do
  def assert_hash(hash, data) do
    if :keccakf1600.hash(:sha3_256, data) != <<hash::256>> do
      raise "invalid hash"
    end
  end

  def hash(data) do
    :keccakf1600.hash(:sha3_256, data)
  end

  def recover_public_key(message, signature, recovery_id) do
    sig_hash = :keccakf1600.hash(:sha3_256, <<message::32>>)

    {:ok, public_key} = :libsecp256k1.ecdsa_recover_compact(
      sig_hash,
      <<signature::512>>,
      :compressed,
      recovery_id
    )
    public_key
  end

  def sign(message, signature) do
    :libsecp256k1.ecdsa_sign_compact(message, :binary.encode_unsigned(signature), :default, <<>>)
  end
end
