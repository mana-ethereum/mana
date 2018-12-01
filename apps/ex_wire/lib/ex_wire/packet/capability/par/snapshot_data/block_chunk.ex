defmodule ExWire.Packet.Capability.Par.SnapshotData.BlockChunk do
  @moduledoc """
  Block chunks contain raw block data: blocks themselves, and their transaction
  receipts. The blocks are stored in the "abridged block" format (referred to
  by AB), and the the receipts are stored in a list: [`receipt_1`: `P`,
  `receipt_2`: `P`, ...] (referred to by RC).
  """

  defmodule BlockHeader do
    @type t :: %__MODULE__{
            # Header fields
            author: EVM.address(),
            state_root: EVM.hash(),
            logs_bloom: <<_::2048>>,
            difficulty: integer(),
            gas_limit: integer(),
            gas_used: integer(),
            timestamp: integer(),
            extra_data: integer(),

            # Ommers and transactions inline
            transactions: list(Blockchain.Transaction.t()),
            transactions_rlp: list(ExRLP.t()),
            ommers: list(Block.Header.t()),
            ommers_rlp: list(ExRLP.t()),

            # Seal fields
            mix_hash: EVM.hash(),
            nonce: <<_::64>>
          }

    defstruct [
      :author,
      :state_root,
      :logs_bloom,
      :difficulty,
      :gas_limit,
      :gas_used,
      :timestamp,
      :extra_data,
      :transactions,
      :transactions_rlp,
      :ommers,
      :ommers_rlp,
      :mix_hash,
      :nonce
    ]
  end

  defmodule BlockData do
    @type t :: %__MODULE__{
            header: BlockHeader.t(),
            receipts: list(Blockchain.Transaction.Receipt.t()),
            receipts_rlp: list(ExRLP.t())
          }
    defstruct [
      :header,
      :receipts,
      :receipts_rlp
    ]
  end

  @type t :: %__MODULE__{
          number: integer(),
          hash: EVM.hash(),
          total_difficulty: integer(),
          block_data_list: list(BlockData.t())
        }

  defstruct number: nil,
            hash: nil,
            total_difficulty: nil,
            block_data_list: []

  @doc """
  Given a `BlockChunk`, serializes for transport within a SnapshotData packet.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk{
      ...>   number: 5,
      ...>   hash: <<6::256>>,
      ...>   total_difficulty: 7,
      ...>   block_data_list: [
      ...>     %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.BlockData{
      ...>       header: %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.BlockHeader{
      ...>         author: <<10::160>>,
      ...>         state_root: <<11::256>>,
      ...>         logs_bloom: <<12::2048>>,
      ...>         difficulty: 13,
      ...>         gas_limit: 14,
      ...>         gas_used: 15,
      ...>         timestamp: 16,
      ...>         extra_data: 17,
      ...>         transactions: [
      ...>           %Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}
      ...>         ],
      ...>         ommers: [
      ...>           %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
      ...>         ],
      ...>         mix_hash: <<18::256>>,
      ...>         nonce: <<19::64>>,
      ...>       },
      ...>       receipts: [
      ...>         %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []}
      ...>       ]
      ...>     }
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.serialize()
      [
        5,
        <<6::256>>,
        7,
        [
          [
            <<10::160>>,
            <<11::256>>,
            <<12::2048>>,
            13,
            14,
            15,
            16,
            17,
            [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
            [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>]],
            <<18::256>>,
            <<19::64>>
          ],
          [
            [<<1,2,3>>, 5, <<2,3,4>>, []]
          ]
        ]
      ]
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(block_chunk = %__MODULE__{}) do
    serialized_block_data =
      for block_data <- block_chunk.block_data_list do
        [
          [
            block_data.header.author,
            block_data.header.state_root,
            block_data.header.logs_bloom,
            block_data.header.difficulty,
            block_data.header.gas_limit,
            block_data.header.gas_used,
            block_data.header.timestamp,
            block_data.header.extra_data,
            Enum.map(block_data.header.transactions, &Blockchain.Transaction.serialize/1),
            Enum.map(block_data.header.ommers, &Block.Header.serialize/1),
            block_data.header.mix_hash,
            block_data.header.nonce
          ],
          Enum.map(block_data.receipts, &Blockchain.Transaction.Receipt.serialize/1)
        ]
      end

    [
      block_chunk.number,
      block_chunk.hash,
      block_chunk.total_difficulty
    ] ++ serialized_block_data
  end

  @doc """
  Given an RLP-encoded `BlockChunk` from a SnapshotData packet, decodes into a
  `BlockChunk` struct.

  ## Examples

      iex> [
      ...>   <<5>>,
      ...>   <<6::256>>,
      ...>   <<7>>,
      ...>   [
      ...>     [
      ...>       <<10::160>>,
      ...>       <<11::256>>,
      ...>       <<12::2048>>,
      ...>       13,
      ...>       14,
      ...>       15,
      ...>       16,
      ...>       17,
      ...>       [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
      ...>       [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]],
      ...>       <<18::256>>,
      ...>       <<19::64>>
      ...>     ],
      ...>     [
      ...>       [<<1,2,3>>, <<5>>, <<2,3,4>>, []]
      ...>     ]
      ...>   ]
      ...> ]
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.deserialize()
      %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk{
        number: 5,
        hash: <<6::256>>,
        total_difficulty: 7,
        block_data_list: [
          %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.BlockData{
            header: %ExWire.Packet.Capability.Par.SnapshotData.BlockChunk.BlockHeader{
              author: <<10::160>>,
              state_root: <<11::256>>,
              logs_bloom: <<12::2048>>,
              difficulty: 13,
              gas_limit: 14,
              gas_used: 15,
              timestamp: 16,
              extra_data: 17,
              transactions: [
                %Blockchain.Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}
              ],
              transactions_rlp: [[<<5>>, <<6>>, <<7>>, <<1::160>>, <<8>>, "hi", <<27>>, <<9>>, <<10>>]],
              ommers: [
                %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
              ],
              ommers_rlp: [[<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>]],
              mix_hash: <<18::256>>,
              nonce: <<19::64>>,
            },
            receipts: [
              %Blockchain.Transaction.Receipt{state: <<1,2,3>>, cumulative_gas: 5, bloom_filter: <<2,3,4>>, logs: []}
            ],
            receipts_rlp: [[<<1,2,3>>, <<5>>, <<2,3,4>>, []]]
          }
        ]
      }
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      number,
      hash,
      total_difficulty
      | serialized_block_data
    ] = rlp

    block_data_list =
      for block_data_rlp <- serialized_block_data do
        [
          [
            author,
            state_root,
            logs_bloom,
            difficulty,
            gas_limit,
            gas_used,
            timestamp,
            extra_data,
            transactions_rlp,
            ommers_rlp,
            mix_hash,
            nonce
          ],
          receipts_rlp
        ] = block_data_rlp

        transactions = Enum.map(transactions_rlp, &Blockchain.Transaction.deserialize/1)
        ommers = Enum.map(ommers_rlp, &Block.Header.deserialize/1)
        receipts = Enum.map(receipts_rlp, &Blockchain.Transaction.Receipt.deserialize/1)

        %BlockData{
          header: %BlockHeader{
            author: author,
            state_root: state_root,
            logs_bloom: logs_bloom,
            difficulty: Exth.maybe_decode_unsigned(difficulty),
            gas_limit: Exth.maybe_decode_unsigned(gas_limit),
            gas_used: Exth.maybe_decode_unsigned(gas_used),
            timestamp: Exth.maybe_decode_unsigned(timestamp),
            extra_data: extra_data,
            transactions: transactions,
            transactions_rlp: transactions_rlp,
            ommers: ommers,
            ommers_rlp: ommers_rlp,
            mix_hash: mix_hash,
            nonce: nonce
          },
          receipts: receipts,
          receipts_rlp: receipts_rlp
        }
      end

    %__MODULE__{
      number: Exth.maybe_decode_unsigned(number),
      hash: hash,
      total_difficulty: Exth.maybe_decode_unsigned(total_difficulty),
      block_data_list: block_data_list
    }
  end
end
