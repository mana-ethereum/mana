defmodule ExWire.Packet.Capability.Par.SnapshotData.StateChunk do
  @moduledoc """
  State chunks store the entire state of a given block. A "rich" account
  structure is used to save space. Each state chunk consists of a list of
  lists, each with two items: an address' sha3 hash and a rich account
  structure correlating with it.
  """

  defmodule RichAccount do
    @moduledoc """
    The rich account structure encodes the usual account data such as the
    nonce, balance, and code, as well as the full storage.

    Note: `code_flag` is a single byte which will determine what the `code`
          data will be:
      * if 0x00, the account has no code and code is the single byte 0x80,
                 signifying RLP empty data.
      * if 0x01, the account has code, and code stores an arbitrary-length list
                 of bytes containing the code.
      * if 0x02, the account has code, and code stores a 32-byte big-endian
                 integer which is the hash of the code. The code’s hash must be
                 substituted if and only if another account which has a smaller
                 account entry has the same code.

    Note: `storage` is a list of the entire account’s storage, where the items
          are RLP lists of length two – the first item being sha3(key), and the
          second item being the storage value. This storage list must be sorted
          in ascending order by key-hash.

    Note: If `storage` is large enough that the rich account structure would
          bring the internal size (see the Validity section) of the chunk to
          over `CHUNK_SIZE`, only the prefix of storage that would keep the
          internal size of the chunk within `CHUNK_SIZE` will be included. We
          will call the unincluded remainder storage'. A new state chunk will
          begin with an account entry of the same account, but with storage set
          to the prefix of storage which will fit in the chunk, and so on.
    """
    @type code_flag :: :no_code | :has_code | :has_repeat_code
    @type storage_tuple :: {EVM.hash(), <<_::256>>}

    @type t :: %__MODULE__{
            nonce: EVM.hash(),
            balance: integer(),
            code_flag: code_flag(),
            code: binary(),
            storage: list(storage_tuple())
          }

    defstruct [
      :nonce,
      :balance,
      :code_flag,
      :code,
      :storage
    ]

    @spec decode_code_flag(0 | 1 | 2) :: code_flag()
    def decode_code_flag(0), do: :no_code
    def decode_code_flag(1), do: :has_code
    def decode_code_flag(2), do: :has_repeat_code

    @spec encode_code_flag(code_flag()) :: 0 | 1 | 2
    def encode_code_flag(:no_code), do: 0
    def encode_code_flag(:has_code), do: 1
    def encode_code_flag(:has_repeat_code), do: 2
  end

  @type account_entry :: {
          EVM.hash(),
          RichAccount.t()
        }

  @type t() :: %__MODULE__{
          account_entries: list(account_entry())
        }

  defstruct account_entries: []

  @doc """
  Given a `StateChunk`, serializes for transport within a SnapshotData packet.

  ## Examples

      iex> %ExWire.Packet.Capability.Par.SnapshotData.StateChunk{
      ...>   account_entries: [
      ...>     {
      ...>       <<1::256>>,
      ...>       %ExWire.Packet.Capability.Par.SnapshotData.StateChunk.RichAccount{
      ...>         nonce: 2,
      ...>         balance: 3,
      ...>         code_flag: :has_code,
      ...>         code: <<5::256>>,
      ...>         storage: [{<<1::256>>, <<2::256>>}]
      ...>       }
      ...>     }
      ...>   ]
      ...> }
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.StateChunk.serialize()
      [
        [ <<1::256>>,
          [
            2,
            3,
            1,
            <<5::256>>,
            [[<<1::256>>, <<2::256>>]]
          ]
        ]
      ]
  """
  @spec serialize(t()) :: ExRLP.t()
  def serialize(state_chunk = %__MODULE__{}) do
    for {hash, rich_account} <- state_chunk.account_entries do
      [
        hash,
        [
          rich_account.nonce,
          rich_account.balance,
          RichAccount.encode_code_flag(rich_account.code_flag),
          rich_account.code,
          for {key, val} <- rich_account.storage do
            [key, val]
          end
        ]
      ]
    end
  end

  @doc """
  Given an RLP-encoded `StateChunk` from a SnapshotData packet, decodes into a
  `StateChunk` struct.

  ## Examples

      iex> [
      ...>   [ <<1::256>>,
      ...>     [
      ...>       2,
      ...>       3,
      ...>       1,
      ...>       <<5::256>>,
      ...>       [[<<1::256>>, <<2::256>>]]
      ...>     ]
      ...>   ]
      ...> ]
      ...> |> ExWire.Packet.Capability.Par.SnapshotData.StateChunk.deserialize()
      %ExWire.Packet.Capability.Par.SnapshotData.StateChunk{
        account_entries: [
          {
            <<1::256>>,
            %ExWire.Packet.Capability.Par.SnapshotData.StateChunk.RichAccount{
              nonce: 2,
              balance: 3,
              code_flag: :has_code,
              code: <<5::256>>,
              storage: [{<<1::256>>, <<2::256>>}]
            }
          }
        ]
      }
  """
  @spec deserialize(ExRLP.t()) :: t()
  def deserialize(rlp) do
    account_entries_rlp = rlp

    account_entries =
      for [hash, rich_account_rlp] <- account_entries_rlp do
        [
          nonce,
          balance,
          encoded_code_flag,
          code,
          storage_rlp
        ] = rich_account_rlp

        storage =
          for [key, val] <- storage_rlp do
            {key, val}
          end

        {hash,
         %RichAccount{
           nonce: Exth.maybe_decode_unsigned(nonce),
           balance: Exth.maybe_decode_unsigned(balance),
           code_flag:
             encoded_code_flag
             |> Exth.maybe_decode_unsigned()
             |> RichAccount.decode_code_flag(),
           code: code,
           storage: storage
         }}
      end

    %__MODULE__{
      account_entries: account_entries
    }
  end
end
