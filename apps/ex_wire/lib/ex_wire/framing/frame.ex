defmodule ExWire.Framing.Frame do
  @moduledoc """
  Handles framing a message for transport in RLPx.

  This is defined in the [RLPx docs[(https://github.com/ethereum/devp2p/blob/master/rlpx.md)
  under Framing section.

  TODO: Handle multi-frame packets, etc.
  TODO: Add tests, etc.
  """

  alias ExthCrypto.Hash.Keccak
  alias ExthCrypto.AES

  @type frame :: binary()

  defmodule Secrets do
    @type t :: %__MODULE__{
      egress_mac: Keccak.keccak_mac,
      ingress_mac: Keccak.keccak_mac,
      mac_secret: binary(),
      symmetric_stream: ExthCrypto.Cipher.stream,
    }

    defstruct [
      :egress_mac,
      :ingress_mac,
      :mac_secret,
      :symmetric_stream
    ]

    def new(egress_mac, ingress_mac, mac_secret, symmetric_key) do
      # initialize AES stream with empty init_vector
      symmetric_stream = AES.stream_init(:ctr, symmetric_key, <<0::size(128)>>)

      %__MODULE{
        egress_mac: egress_mac,
        ingress_mac: ingress_mac,
        mac_secret: mac_secret,
        symmetric_stream: symmetric_stream
      }
    end
  end

  @spec frame(packet_type, packet_data, Secrets.t) :: {frame, Secrets.t}
  def frame(packet_type, packet_data, frame_secrets=%Secrets{egress_mac: egress_mac, symmetric_stream: symmetric_stream}) do
    # frame:
    #     normal: rlp(packet-type) [|| rlp(packet-data)] || padding
    #     chunked-0: rlp(packet-type) || rlp(packet-data...)
    #     chunked-n: rlp(...packet-data) || padding
    # padding: zero-fill to 16-byte boundary (only necessary for last frame)
    frame_unpadded =
      ExRLP.encode(packet_type) <> (if packet_data, do: ExRLP.encode(packet_data), else: <<>>)

    # frame-size: 3-byte integer size of frame, big endian encoded (excludes padding)
    frame_size_int = byte_size(frame)
    frame_size = <<frame_size_int::size(24)>>

    # assert! total-packet-size: < 2**32

    frame_padding_bits = ( 16 - rem(frame_size_int, 16) ) *
    frame = frame_unpadded <> <<0::size(frame_padding_bits)>>

    # header-data:
    #   normal: rlp.list(protocol-type[, context-id])
    #   chunked-0: rlp.list(protocol-type, context-id, total-packet-size)
    #   chunked-n: rlp.list(protocol-type, context-id)
    #   values:
    #       protocol-type: < 2**16
    #       context-id: < 2**16 (optional for normal frames)
    #       total-packet-size: < 2**32
    protocol_type = <<>>
    context_id = <<>>
    header_data = [protocol_type, context_id] |> ExRLP.encode()

    # header: frame-size || header-data || padding
    header = frame_size <> header_data <> padding

    # :crypto.exor(ExthCrypto.AES.encrypt(egress_mac, :ctr, mac_secret)
    {symmetric_stream, header_enc} = ExthCrypto.AES.stream_encrypt(header, symmetric_stream)

    # header-mac: right128 of egress-mac.update(aes(mac-secret,egress-mac) ^ header-ciphertext).digest
    # from EncryptedConnection::update_mac(&mut self.egress_mac, &mut self.mac_encoder,  &packet[0..16]);
    egress_mac = Keccak.update_mac(egress_mac, mac_secret, header_enc))
    header_mac = Keccak.final_mac(egress_mac) # take on right 128 bits

    # :crypto.exor(ExthCrypto.AES.encrypt(egress_mac, :ctr, mac_secret), header_ciphertext)
    {symmetric_stream, frame_enc} = ExthCrypto.AES.stream_encrypt(frame, symmetric_stream)

    # update egress_mac with frame_enc??
    # self.egress_mac.update(&packet[32..(32 + len + padding)]);
    # egress_mac = :keccakf1600.update(egress_mac, mac_secret, header_enc))

    # frame-mac: right128 of egress-mac.update(aes(mac-secret,egress-mac) ^ right128(egress-mac.update(frame-ciphertext).digest))
    # from EncryptedConnection::update_mac(&mut self.egress_mac, &mut self.mac_encoder, &[0u8; 0]);
    egress_mac = Keccak.update_mac(egress_mac, mac_secret, 0)
    frame_mac = Keccak.final_mac(egress_mac) # take on right 128 bits

    # egress-mac: h256, continuously updated with egress-bytes*
    # ingress-mac: h256, continuously updated with ingress-bytes*

    # Single-frame packet:
    # header || header-mac || frame || frame-mac
    frame = header_enc <> header_mac <> frame_enc <> frame_mac

    # Return packet and secrets with updated egress mac and symmetric encoder
    {frame, %{frame_secrets | egress_mac: egress_mac, symmetric_stream: symmetric_stream}}
  end
end