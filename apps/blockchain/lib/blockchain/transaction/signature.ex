defmodule Blockchain.Transaction.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.
  """

  @type public_key :: <<_::512>>
  @type private_key :: <<_::256>>
  @type recovery_id :: <<_::8>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()

  # The follow are the maximum value for x in the signature, as defined in Eq.(212)
  @secp256k1n         115792089237316195423570985008687907852837564279074904382605163141518161494337
  @secp256k1n_2       round(:math.floor(@secp256k1n / 2))
  @base_recovery_id   27

  @doc """
  Given a private key, returns a public key.

  This covers Eq.(206) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.Signature.get_public_key(<<1::256>>)
      {:ok, <<4, 121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149,
              206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40, 217, 89,
              242, 129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163,
              196, 101, 93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180,
              72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

      iex> Blockchain.Transaction.Signature.get_public_key(<<1>>)
      {:error, "Private key size not 32 bytes"}
  """
  @spec get_public_key(private_key) :: {:ok, public_key} | {:error, String.t}
  def get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  ## Examples

    iex> Blockchain.Transaction.Signature.sign_hash(<<2::256>>, <<1::256>>)
    {28,
     38938543279057362855969661240129897219713373336787331739561340553100525404231,
     23772455091703794797226342343520955590158385983376086035257995824653222457926}

    iex> Blockchain.Transaction.Signature.sign_hash(<<5::256>>, <<1::256>>)
    {27,
     74927840775756275467012999236208995857356645681540064312847180029125478834483,
     56037731387691402801139111075060162264934372456622294904359821823785637523849}
  """
  @spec sign_hash(BitHelper.keccak_hash, private_key) :: {hash_v, hash_r, hash_s}
  def sign_hash(hash, private_key) do
    public_key = get_public_key(private_key)

    {:ok, <<r::size(256), s::size(256)>>, recovery_id} = :libsecp256k1.ecdsa_sign_compact(hash, private_key, :default, <<>>)

    {@base_recovery_id + recovery_id, r, s}
  end

  @doc """
  Recovers a public key from a signed hash.

  This implements Eq.(208) of the Yellow Paper, adapted from https://stackoverflow.com/a/20000007

  ## Examples

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 28, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:ok, <<4, 121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149,
            206, 135, 11, 7, 2, 155, 252, 219, 45, 206, 40, 217, 89, 242,
            129, 91, 22, 248, 23, 152, 72, 58, 218, 119, 38, 163, 196, 101,
            93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180, 72, 166, 133,
            84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 55, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:error, "Recovery id invalid 0-3"}
  """
  @spec recover_public(BitHelper.keccak_hash, hash_v, hash_r, hash_s) :: {:ok, public_key} | {:error, String.t}
  def recover_public(hash, v, r, s) do
    signature = :binary.encode_unsigned(r) <> :binary.encode_unsigned(s)
    recovery_id = v - @base_recovery_id

    case :libsecp256k1.ecdsa_recover_compact(hash, signature, :uncompressed, recovery_id) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end

  @doc """
  Verifies a given signature is valid, as defined in Eq.(209), Eq.(210), Eq.(211)

  ## Examples

    iex> Blockchain.Transaction.Signature.is_signature_valid?(true, 1, 1, 27)
    true

    iex> Blockchain.Transaction.Signature.is_signature_valid?(true, 1, 1, 20) # invalid v
    false

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> Blockchain.Transaction.Signature.is_signature_valid?(false, secp256k1n - 1, 1, 28) # r okay
    true

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> Blockchain.Transaction.Signature.is_signature_valid?(false, secp256k1n + 1, 1, 28) # r too high
    false

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> Blockchain.Transaction.Signature.is_signature_valid?(false, 1, secp256k1n + 1, 28) # s too high for non-homestead
    false

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> Blockchain.Transaction.Signature.is_signature_valid?(false, 1, secp256k1n - 1, 28) # s okay for non-homestead
    true

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> Blockchain.Transaction.Signature.is_signature_valid?(true, 1, secp256k1n - 1, 28) # s too high for homestead
    false

    iex> secp256k1n = 115792089237316195423570985008687907852837564279074904382605163141518161494337
    iex> secp256k1n_2 = round(:math.floor(secp256k1n / 2))
    iex> Blockchain.Transaction.Signature.is_signature_valid?(true, secp256k1n_2 - 1, 1, 28) # s okay for homestead
    true
  """
  @spec is_signature_valid?(boolean(), integer(), integer(), integer()) :: boolean()
  def is_signature_valid?(is_homestead, r, s, v) do
    r > 0 and
    r < @secp256k1n and
    s > 0 and
    ( if is_homestead, do: s < @secp256k1n_2, else: s < @secp256k1n ) and
    ( v == 27 || v == 28 )
  end

  @doc """
  Returns a hash of a given transaction according to the
  formula defined in Eq.(214) and Eq.(215) of the Yellow Paper.

  TODO: Are we supposed to RLP encode Ls before hashing, or maybe
        just concatencate the fields? Confused about Eq 214/5.

  ## Examples

      iex> Blockchain.Transaction.Signature.transaction_hash(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>})
      <<127, 113, 209, 76, 19, 196, 2, 206, 19, 198, 240, 99, 184, 62, 8, 95, 9, 122, 135, 142, 51, 22, 61, 97, 70, 206, 206, 39, 121, 54, 83, 27>>

      iex> Blockchain.Transaction.Signature.transaction_hash(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>})
      <<225, 195, 128, 181, 3, 211, 32, 231, 34, 10, 166, 198, 153, 71, 210, 118, 51, 117, 22, 242, 87, 212, 229, 37, 71, 226, 150, 160, 50, 203, 127, 180>>
  """
  @spec transaction_hash(Blockchain.Transaction.t) :: BitHelper.keccak_hash
  def transaction_hash(trx) do
    Blockchain.Transaction.serialize(trx)
      |> Enum.take(6)
      |> ExRLP.encode()
      |> BitHelper.kec()
  end

  @doc """
  Takes a given transaction and returns a version signed
  with the given private key. This is defined in Eq.(216) and
  Eq.(217) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.Signature.sign_transaction(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>}, <<1::256>>)
      %Blockchain.Transaction{data: <<>>, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 97037709922803580267279977200525583527127616719646548867384185721164615918250, s: 31446571475787755537574189222065166628755695553801403547291726929250860527755, to: "", v: 27, value: 5}
  """
  @spec sign_transaction(Blockchain.Transaction.t, private_key) :: Blockchain.Transaction.t
  def sign_transaction(trx, private_key) do

    {v, r, s} = trx
      |> transaction_hash()
      |> sign_hash(private_key)

    %{trx | v: v, r: r, s: s}
  end

  @doc """
  Given a private key, this will return an associated
  ethereum address, as defined in Eq.(213).

  This returns the rightmost 160-bits of the Keecak-256 of the public key.

  ## Examples

      iex> Blockchain.Transaction.Signature.address_from_private(<<1::256>>)
      <<125, 110, 153, 187, 138, 191, 140, 192, 19, 187, 14, 145, 45, 11, 23, 101, 150, 254, 123, 136>>
  """
  @spec address_from_private(private_key) :: EVM.address
  def address_from_private(private_key) do
    {:ok, public_key} = get_public_key(private_key)

    address_from_public(public_key)
  end

  @doc """
  Given a public key, this will return an associated
  ethereum address, as defined (in part) in Eq.(213).

  This returns the rightmost 160-bits of the Keecak-256 of the public key.

  ## Examples

      iex> Blockchain.Transaction.Signature.address_from_public(<<1::256>>)
      <<113, 126, 106, 50, 12, 244, 75, 74, 250, 194, 176, 115, 45, 159, 203, 226, 183, 250, 12, 246>>
  """
  @spec address_from_public(public_key) :: EVM.address
  def address_from_public(public_key) do
    public_key
      |> BitHelper.kec()
      |> BitHelper.mask_bitstring(20*8)
  end

  @doc """
  Given a transaction, we will determine the sender of the message.

  This is defined in Eq.(218) of the Yellow Paper, verified by Eq.(219).

  ## Examples

      iex> Blockchain.Transaction.Signature.sender(%Blockchain.Transaction{data: nil, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 38889131630470350300468726261158724183878062819625353581392042110782473464074, s: 56013001490976921811414879795854011730332692343890561111314022658085426919315, to: "", v: 27, value: 5})
      {:ok, <<78, 5, 165, 161, 24, 170, 36, 120, 35, 15, 72, 69, 245, 223, 223, 115, 128, 119, 32, 137>>}

      iex> Blockchain.Transaction.Signature.sender(%Blockchain.Transaction{data: nil, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 0, s: 0, to: "", v: 0, value: 5})
      {:error, "Recovery id invalid 0-3"}
  """
  @spec sender(Blockchain.Transaction.t) :: {:ok, EVM.address} | {:error, String.t}
  def sender(trx) do
    with {:ok, public_key} <- recover_public(transaction_hash(trx), trx.v, trx.r, trx.s) do
       {:ok, address_from_public(public_key)}
    end
  end

  # Enforces a low-s vaue or something
  # From https://stackoverflow.com/a/36749436
  # @spec get_r_s(signature) :: {v, r, s}
  # def get_r_s(sig) do
  #   len  = sig |> :binary.at(1)
  #   rlen = sig |> :binary.at(3)
  #   r    = sig |> :binary.part(4, rlen)
  #   slen = sig |> :binary.at(rlen + 5)
  #   s    = sig |> :binary.part(rlen + 6, slen)

  #   {:"ECDSA-Sig-Value", r, s} = :public_key.der_decode(:'ECDSA-Sig-Value', signature)

  #   # sint = s   |> :binary.decode_unsigned
  #   # if sint > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0 do
  #   #   s = (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - sint) |> :binary.encode_unsigned
  #   #   slen = s |> :binary.bin_to_list |> Enum.count
  #   #   len = rlen + slen + 4
  #   # end
  #   # <<48, len, 2>> <> <<rlen>> <> r <> <<2, slen>> <> s

  #   {v, r, s}
  # end

end