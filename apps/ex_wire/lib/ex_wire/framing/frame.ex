defmodule ExWire.Framing.Frame do
  @moduledoc """
  Handles framing a message for transport in RLPx.

  This is defined in the [RLPx docs[(https://github.com/ethereum/devp2p/blob/master/rlpx.md)
  under Framing section.

  TODO: Handle multi-frame packets, etc.
  TODO: Add tests, etc.
  """

  alias ExthCrypto.{AES, MAC}
  alias ExWire.Framing.Secrets

  @type frame :: binary()

  @spec frame(integer(), ExRLP.t(), Secrets.t()) :: {frame, Secrets.t()}
  def frame(
        packet_type,
        packet_data,
        frame_secrets = %Secrets{
          egress_mac: egress_mac,
          encoder_stream: encoder_stream,
          mac_encoder: mac_encoder,
          mac_secret: mac_secret
        }
      ) do
    # frame:
    #     normal: rlp(packet-type) [|| rlp(packet-data)] || padding
    #     chunked-0: rlp(packet-type) || rlp(packet-data...)
    #     chunked-n: rlp(...packet-data) || padding
    # padding: zero-fill to 16-byte boundary (only necessary for last frame)
    frame_unpadded =
      ExRLP.encode(packet_type) <> if packet_data, do: ExRLP.encode(packet_data), else: <<>>

    # frame-size: 3-byte integer size of frame, big endian encoded (excludes padding)
    frame_size_int = byte_size(frame_unpadded)
    frame_size = <<frame_size_int::size(24)>>

    # assert! total-packet-size: < 2**32
    frame_padding = padding_for(frame_size_int, 16)

    # header-data:
    #   normal: rlp.list(protocol-type[, context-id])
    #   chunked-0: rlp.list(protocol-type, context-id, total-packet-size)
    #   chunked-n: rlp.list(protocol-type, context-id)
    #   values:
    #       protocol-type: < 2**16
    #       context-id: < 2**16 (optional for normal frames)
    #       total-packet-size: < 2**32
    # protocol_type = <<>>
    # context_id = <<>>
    # header_data = [protocol_type, context_id] |> ExRLP.encode()
    # Honestly, this is what Geth and Parity use as a header data.
    header_data = <<0xC2, 0x80, 0x80>>
    header_padding = padding_for(byte_size(frame_size <> header_data), 16)

    # header: frame-size || header-data || padding
    header = frame_size <> header_data <> header_padding

    {encoder_stream, header_enc} = AES.stream_encrypt(header, encoder_stream)

    # header-mac: right128 of egress-mac.update(aes(mac-secret,egress-mac) ^ header-ciphertext).digest
    egress_mac = update_mac(egress_mac, mac_encoder, mac_secret, header_enc)
    header_mac = egress_mac |> MAC.final() |> Binary.take(16)

    {encoder_stream, frame_unpadded_enc} = AES.stream_encrypt(frame_unpadded, encoder_stream)

    {encoder_stream, frame_padding_enc} =
      if byte_size(frame_padding) > 0 do
        AES.stream_encrypt(frame_padding, encoder_stream)
      else
        {encoder_stream, <<>>}
      end

    frame_enc = frame_unpadded_enc <> frame_padding_enc

    # frame-mac: right128 of egress-mac.update(aes(mac-secret,egress-mac) ^
    #            right128(egress-mac.update(frame-ciphertext).digest))
    # from EncryptedConnection::update_mac(&mut self.egress_mac, &mut self.mac_encoder, &[0u8; 0]);
    egress_mac = MAC.update(egress_mac, frame_enc)
    egress_mac = update_mac(egress_mac, mac_encoder, mac_secret, nil)
    frame_mac = egress_mac |> MAC.final() |> Binary.take(16)

    # egress-mac: h256, continuously updated with egress-bytes*
    # ingress-mac: h256, continuously updated with ingress-bytes*

    # Single-frame packet:
    # header || header-mac || frame || frame-mac
    frame = header_enc <> header_mac <> frame_enc <> frame_mac

    # Return packet and secrets with updated egress mac and symmetric encoder
    {frame, %{frame_secrets | egress_mac: egress_mac, encoder_stream: encoder_stream}}
  end

  @spec unframe(binary(), Secrets.t()) ::
          {:ok, integer(), binary(), binary(), Secrets.t()} | {:error, String.t()}
  def unframe(
        frame,
        frame_secrets = %Secrets{
          ingress_mac: ingress_mac,
          decoder_stream: decoder_stream,
          mac_encoder: mac_encoder,
          mac_secret: mac_secret
        }
      ) do
    <<
      # is header always 128 bits?
      header_enc::binary-size(16),
      header_mac::binary-size(16),
      frame_rest::binary()
    >> = frame

    # verify header mac
    ingress_mac = update_mac(ingress_mac, mac_encoder, mac_secret, header_enc)
    expected_header_mac = ingress_mac |> MAC.final() |> Binary.take(16)

    if expected_header_mac != header_mac do
      {:error, "Failed to match header ingress mac"}
    else
      {decoder_stream, header} = AES.stream_decrypt(header_enc, decoder_stream)

      <<
        frame_size::integer-size(24),
        _header_data_and_padding::binary()
      >> = header

      # TODO: We should read the header? But, it's unused by all clients.
      # header_rlp = header_data_and_padding |> ExRLP.decode
      # protocol_id = Enum.at(header_rlp, 0) |> ExRLP.decode

      frame_padding_bytes = padding_size(frame_size, 16)

      if byte_size(frame_rest) < frame_size + frame_padding_bytes + 16 do
        {:error, "Insufficent data"}
      else
        # let's go and ignore the entire header data....
        <<
          frame_enc::binary-size(frame_size),
          frame_padding::binary-size(frame_padding_bytes),
          frame_mac::binary-size(16),
          frame_rest::binary()
        >> = frame_rest

        frame_enc_with_padding = frame_enc <> frame_padding

        ingress_mac = MAC.update(ingress_mac, frame_enc_with_padding)
        ingress_mac = update_mac(ingress_mac, mac_encoder, mac_secret, nil)
        expected_frame_mac = ingress_mac |> MAC.final() |> Binary.take(16)

        if expected_frame_mac != frame_mac do
          {:error, "Failed to match frame ingress mac"}
        else
          {decoder_stream, frame_with_padding} =
            AES.stream_decrypt(frame_enc_with_padding, decoder_stream)

          <<
            frame::binary-size(frame_size),
            _frame_padding::binary()
          >> = frame_with_padding

          <<
            packet_type_rlp::binary-size(1),
            packet_data_rlp::binary()
          >> = frame

          {
            :ok,
            packet_type_rlp |> ExRLP.decode() |> :binary.decode_unsigned(),
            packet_data_rlp |> ExRLP.decode(),
            frame_rest,
            %{frame_secrets | ingress_mac: ingress_mac, decoder_stream: decoder_stream}
          }
        end
      end
    end
  end

  # updateMAC reseeds the given hash with encrypted seed.
  # it returns the first 16 bytes of the hash sum after seeding.
  @spec update_mac(
          MAC.mac_inst(),
          ExthCrypto.Cipher.cipher(),
          ExthCrypto.Key.symmetric_key(),
          binary() | nil
        ) :: MAC.mac_inst()
  defp update_mac(mac, mac_encoder, mac_secret, seed) do
    final = mac |> MAC.final() |> Binary.take(16)

    enc = final |> ExthCrypto.Cipher.encrypt(mac_secret, mac_encoder) |> Binary.take(-16)

    enc_xored = ExthCrypto.Math.xor(enc, if(seed, do: seed, else: final))

    MAC.update(mac, enc_xored)
  end

  @spec padding_size(integer(), integer()) :: integer()
  defp padding_size(given_size, to_size) do
    rem(to_size - rem(given_size, to_size), to_size)
  end

  @spec padding_for(integer(), integer()) :: binary()
  defp padding_for(given_size, to_size) do
    padding_bits = padding_size(given_size, to_size) * 8

    <<0::size(padding_bits)>>
  end
end
