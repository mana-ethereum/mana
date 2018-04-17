defmodule Blockchain.Transaction.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  """

  @type public_key :: <<_::512>>
  @type private_key :: <<_::256>>
  @type recovery_id :: <<_::8>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()

  # The follow are the maximum value for x in the signature, as defined in Eq.(212)
  @secp256k1n               115792089237316195423570985008687907852837564279074904382605163141518161494337
  @secp256k1n_2             round(:math.floor(@secp256k1n / 2))
  @base_recovery_id         27
  @base_recovery_id_eip_155 35

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

    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> private_key = "4646464646464646464646464646464646464646464646464646464646464646" |> BitHelper.from_hex
    iex> Blockchain.Transaction.Signature.sign_hash(hash, private_key, 1)
    { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
  """
  @spec sign_hash(BitHelper.keccak_hash, private_key, integer() | nil) :: {hash_v, hash_r, hash_s}
  def sign_hash(hash, private_key, chain_id \\ nil) do

    {:ok, <<r::size(256), s::size(256)>>, recovery_id} = :libsecp256k1.ecdsa_sign_compact(hash, private_key, :default, <<>>)

    # Fork Ψ EIP-155
    recovery_id = if chain_id do
      chain_id * 2 + @base_recovery_id_eip_155 + recovery_id
    else
      @base_recovery_id + recovery_id
    end

    {recovery_id, r, s}
  end

  @doc """
  Recovers a public key from a signed hash.

  This implements Eq.(208) of the Yellow Paper, adapted from https://stackoverflow.com/a/20000007

  ## Examples

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 28, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:ok, <<121, 190, 102, 126, 249, 220, 187, 172, 85, 160, 98, 149, 206, 135, 11, 7, 2,
            155, 252, 219, 45, 206, 40, 217, 89, 242, 129, 91, 22, 248, 23, 152, 72, 58,
            218, 119, 38, 163, 196, 101, 93, 164, 251, 252, 14, 17, 8, 168, 253, 23, 180,
            72, 166, 133, 84, 25, 156, 71, 208, 143, 251, 16, 212, 184>>}

    iex> Blockchain.Transaction.Signature.recover_public(<<2::256>>, 55, 38938543279057362855969661240129897219713373336787331739561340553100525404231, 23772455091703794797226342343520955590158385983376086035257995824653222457926)
    {:error, "Recovery id invalid 0-3"}

    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> v = 27
    iex> r = 18515461264373351373200002665853028612451056578545711640558177340181847433846
    iex> s = 46948507304638947509940763649030358759909902576025900602547168820602576006531
    iex> Blockchain.Transaction.Signature.recover_public(hash, v, r, s)
    {:ok,
      <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133,
        226, 23, 248, 205, 98, 140, 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40,
        202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219, 152, 161, 104, 5, 33,
        21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>}

    iex> { v, r, s } = { 37, 18515461264373351373200002665853028612451056578545711640558177340181847433846, 46948507304638947509940763649030358759909902576025900602547168820602576006531 }
    iex> data = "ec098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a764000080018080" |> BitHelper.from_hex
    iex> hash = data |> BitHelper.kec
    iex> Blockchain.Transaction.Signature.recover_public(hash, v, r, s, 1)
    {:ok, <<75, 194, 163, 18, 101, 21, 63, 7, 231, 14, 11, 171, 8, 114, 78, 107, 133,
            226, 23, 248, 205, 98, 140, 235, 98, 151, 66, 71, 187, 73, 51, 130, 206, 40,
            202, 183, 154, 215, 17, 158, 225, 173, 62, 188, 219, 152, 161, 104, 5, 33,
            21, 48, 236, 198, 207, 239, 161, 184, 142, 109, 255, 153, 35, 42>>}
  """
  @spec recover_public(BitHelper.keccak_hash, hash_v, hash_r, hash_s, integer() | nil) :: {:ok, public_key} | {:error, String.t}
  def recover_public(hash, v, r, s, chain_id \\ nil) do
    signature = BitHelper.pad(:binary.encode_unsigned(r), 32) <> BitHelper.pad(:binary.encode_unsigned(s), 32)

    # Fork Ψ EIP-155
    recovery_id = if not is_nil(chain_id) and uses_chain_id?(v) do
      v - chain_id * 2 - @base_recovery_id_eip_155
    else
      v - @base_recovery_id
    end

    case :libsecp256k1.ecdsa_recover_compact(hash, signature, :uncompressed, recovery_id) do
      {:ok, <<_byte::8, public_key::binary()>>} -> {:ok, public_key}
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

  Note: As per EIP-155 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md),
        we will append the chain-id and nil elements to the serialized transaction.

  ## Examples

      iex> Blockchain.Transaction.Signature.transaction_hash(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>})
      <<127, 113, 209, 76, 19, 196, 2, 206, 19, 198, 240, 99, 184, 62, 8, 95, 9, 122, 135, 142, 51, 22, 61, 97, 70, 206, 206, 39, 121, 54, 83, 27>>

      iex> Blockchain.Transaction.Signature.transaction_hash(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>})
      <<225, 195, 128, 181, 3, 211, 32, 231, 34, 10, 166, 198, 153, 71, 210, 118, 51, 117, 22, 242, 87, 212, 229, 37, 71, 226, 150, 160, 50, 203, 127, 180>>

      iex> Blockchain.Transaction.Signature.transaction_hash(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1>>, value: 5, data: <<1>>}, 1)
      <<132, 79, 28, 4, 212, 58, 235, 38, 66, 211, 167, 102, 36, 58, 229, 88, 238, 251, 153, 23, 121, 163, 212, 64, 83, 111, 200, 206, 54, 43, 112, 53>>
  """
  @spec transaction_hash(Blockchain.Transaction.t, integer() | nil) :: BitHelper.keccak_hash
  def transaction_hash(trx, chain_id \\ nil) do
    Blockchain.Transaction.serialize(trx, false)
      |> Kernel.++(if chain_id, do: [chain_id |> :binary.encode_unsigned, <<>>, <<>>], else: []) # See EIP-155
      |> ExRLP.encode
      |> BitHelper.kec()
  end

  @doc """
  Takes a given transaction and returns a version signed
  with the given private key. This is defined in Eq.(216) and
  Eq.(217) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Transaction.Signature.sign_transaction(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>}, <<1::256>>)
      %Blockchain.Transaction{data: <<>>, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 97037709922803580267279977200525583527127616719646548867384185721164615918250, s: 31446571475787755537574189222065166628755695553801403547291726929250860527755, to: "", v: 27, value: 5}

      iex> Blockchain.Transaction.Signature.sign_transaction(%Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<>>, value: 5, init: <<1>>}, <<1::256>>, 1)
      %Blockchain.Transaction{data: <<>>, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 25739987953128435966549144317523422635562973654702886626580606913510283002553, s: 41423569377768420285000144846773344478964141018753766296386430811329935846420, to: "", v: 38, value: 5}
  """
  @spec sign_transaction(Blockchain.Transaction.t, private_key, integer() | nil) :: Blockchain.Transaction.t
  def sign_transaction(trx, private_key, chain_id \\ nil) do

    {v, r, s} = trx
      |> transaction_hash(chain_id)
      |> sign_hash(private_key, chain_id)

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
      {:ok, <<97, 159, 86, 232, 190, 208, 127, 225, 150, 192, 219, 196, 27, 82, 226, 188, 100, 129, 123, 58>>}

      iex> Blockchain.Transaction.Signature.sender(%Blockchain.Transaction{data: nil, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 38889131630470350300468726261158724183878062819625353581392042110782473464074, s: 56013001490976921811414879795854011730332692343890561111314022658085426919315, to: "", v: 37, value: 5}, 1)
      {:ok, <<193, 199, 91, 238, 113, 76, 188, 186, 97, 187, 114, 56, 173, 211, 129, 121, 109, 144, 30, 253>>}

      iex> Blockchain.Transaction.Signature.sender(%Blockchain.Transaction{data: nil, gas_limit: 7, gas_price: 6, init: <<1>>, nonce: 5, r: 0, s: 0, to: "", v: 0, value: 5})
      {:error, "Recovery id invalid 0-3"}
  """
  @spec sender(Blockchain.Transaction.t, integer() | nil) :: {:ok, EVM.address} | {:error, String.t}
  def sender(trx, chain_id \\ nil) do
    # Ignore chain_id if transaction has a `v` value before EIP-155 minimum
    chain_id = if not uses_chain_id?(trx.v), do: nil, else: chain_id

    with {:ok, public_key} <- recover_public(transaction_hash(trx, chain_id), trx.v, trx.r, trx.s, chain_id) do
      {:ok, address_from_public(public_key)}
    end
  end

  @spec uses_chain_id?(hash_v) :: boolean()
  defp uses_chain_id?(v) do
    v >= @base_recovery_id_eip_155
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