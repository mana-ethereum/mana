defmodule EthCore.Block.Header do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  For more information, see Section 4.3 of the Yellow Paper.
  """

  alias ExthCrypto.Hash.Keccak
  alias EthCore.Block.Header.Validation
  alias MerklePatriciaTree.Trie

  @empty_trie Trie.empty_trie_root_hash()
  @empty_keccak [] |> ExRLP.encode() |> Keccak.kec()

  # H_p P(B_H)H_r
  defstruct parent_hash: nil,
            # H_o KEC(RLP(L∗H(B_U)))
            ommers_hash: @empty_keccak,
            # H_c
            beneficiary: nil,
            # H_r TRIE(LS(Π(σ, B)))
            state_root: @empty_trie,
            # H_t TRIE({∀i < kBTk, i ∈ P : p(i, LT(B_T[i]))})
            transactions_root: @empty_trie,
            # H_e TRIE({∀i < kBRk, i ∈ P : p(i, LR(B_R[i]))})
            receipts_root: @empty_trie,
            # H_b bloom
            logs_bloom: <<0::2048>>,
            # H_d
            difficulty: nil,
            # H_i
            number: nil,
            # H_l
            gas_limit: 0,
            # H_g
            gas_used: 0,
            # H_s
            timestamp: nil,
            # H_x
            extra_data: <<>>,
            # H_m
            mix_hash: nil,
            # H_n
            nonce: nil

  # As defined in section 4.3
  @type t :: %__MODULE__{
          parent_hash: EVM.hash(),
          ommers_hash: EVM.trie_root(),
          beneficiary: EVM.address() | nil,
          state_root: EVM.trie_root(),
          transactions_root: EVM.trie_root(),
          receipts_root: EVM.trie_root(),
          # TODO
          logs_bloom: binary(),
          difficulty: integer() | nil,
          number: integer() | nil,
          gas_limit: EVM.val(),
          gas_used: EVM.val(),
          timestamp: EVM.timestamp() | nil,
          extra_data: binary(),
          mix_hash: EVM.hash() | nil,
          # TODO: 64-bit hash?
          nonce: <<_::64>> | nil
        }

  # The start of the Homestead block, as defined in EIP-606:
  # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-606.md
  @homestead_block 1_150_000

  # D_0 is the difficulty of the genesis block.
  # As defined in Eq.(42)
  @initial_difficulty 131_072

  # Mimics d_0 in Eq.(42), but variable on different chains
  @minimum_difficulty @initial_difficulty

  # Eq.(43)
  @difficulty_bound_divisor 2048

  # Constant from Eq.(47)
  @gas_limit_bound_divisor 1024

  # Eq.(47)
  @min_gas_limit 125_000

  @doc """
  Returns the block that defines the start of Homestead.

  This should be a constant, but it's configurable on different
  chains, and as such, as allow you to pass that configuration
  variable (which ends up making this the identity function, if so).
  """
  @spec homestead(integer()) :: integer()
  def homestead(homestead_block \\ @homestead_block), do: homestead_block

  @doc """
  This functions encode a header into a value that can
  be RLP encoded. This is defined as L_H Eq.(34) in the Yellow Paper.
  """
  @spec serialize(t) :: ExRLP.t()
  def serialize(h) do
    [
      # H_p
      h.parent_hash,
      # H_o
      h.ommers_hash,
      # H_c
      h.beneficiary,
      # H_r
      h.state_root,
      # H_t
      h.transactions_root,
      # H_e
      h.receipts_root,
      # H_b
      h.logs_bloom,
      # H_d
      h.difficulty,
      # H_i
      if(h.number == 0, do: <<>>, else: h.number),
      # H_l
      h.gas_limit,
      # H_g
      if(h.number == 0, do: <<>>, else: h.gas_used),
      # H_s
      h.timestamp,
      # H_x
      h.extra_data,
      # H_m
      h.mix_hash,
      # H_n
      h.nonce
    ]
  end

  @doc """
  Deserializes a block header from an RLP encodable structure.
  This effectively undoes the encoding defined in L_H Eq.(34) of the Yellow Paper.
  """
  @spec deserialize(ExRLP.t()) :: t
  def deserialize(rlp) do
    [
      parent_hash,
      ommers_hash,
      beneficiary,
      state_root,
      transactions_root,
      receipts_root,
      logs_bloom,
      difficulty,
      number,
      gas_limit,
      gas_used,
      timestamp,
      extra_data,
      mix_hash,
      nonce
    ] = rlp

    %__MODULE__{
      parent_hash: parent_hash,
      ommers_hash: ommers_hash,
      beneficiary: beneficiary,
      state_root: state_root,
      transactions_root: transactions_root,
      receipts_root: receipts_root,
      logs_bloom: logs_bloom,
      difficulty: :binary.decode_unsigned(difficulty),
      number: :binary.decode_unsigned(number),
      gas_limit: :binary.decode_unsigned(gas_limit),
      gas_used: :binary.decode_unsigned(gas_used),
      timestamp: :binary.decode_unsigned(timestamp),
      extra_data: extra_data,
      mix_hash: mix_hash,
      nonce: nonce
    }
  end

  @doc """
  Computes hash of a block header,
  which is simply the hash of the serialized block header.

  This is defined in Eq.(33) of the Yellow Paper.
  """
  @spec hash(t) :: EVM.hash()
  def hash(header) do
    header
    |> serialize()
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  @doc """
  Given a parent header and options returns a new child header.
  """
  @spec new_child(t(), keyword()) :: t()
  def new_child(parent_header, opts) do
    timestamp = opts[:timestamp] || System.system_time(:second)
    beneficiary = opts[:beneficiary] || nil
    extra_data = opts[:extra_data] || <<>>
    state_root = opts[:state_root] || parent_header.state_root

    %__MODULE__{
      state_root: state_root,
      timestamp: timestamp,
      extra_data: extra_data,
      beneficiary: beneficiary
    }
  end

  @doc """
  Returns true if the block header is valid.
  This defines Eq.(50) of the Yellow Paper,
  commonly referred to as V(H).

  # TODO: Add proof of work check

  ## Examples

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000}, nil)
      :valid

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 0, difficulty: 5, gas_limit: 5}, nil, true)
      {:invalid, [:invalid_difficulty, :invalid_gas_limit]}

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      :valid

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 1, difficulty: 131_000, gas_limit: 200_000, timestamp: 65}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, true)
      {:invalid, [:invalid_difficulty]}

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 45}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:child_timestamp_invalid]}

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 1, difficulty: 131_136, gas_limit: 300_000, timestamp: 65}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:invalid_gas_limit]}

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 2, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:child_number_invalid]}

      iex> EthCore.Block.Header.validate(%EthCore.Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65, extra_data: "0123456789012345678901234567890123456789"}, %EthCore.Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:extra_data_too_large]}
  """
  @spec validate(t, t | nil, integer(), integer(), integer(), integer(), integer(), integer()) ::
          :valid | {:invalid, [atom()]}
  def validate(
        header,
        parent_header,
        homestead_block \\ @homestead_block,
        initial_difficulty \\ @initial_difficulty,
        minimum_difficulty \\ @minimum_difficulty,
        difficulty_bound_divisor \\ @difficulty_bound_divisor,
        gas_limit_bound_divisor \\ @gas_limit_bound_divisor,
        min_gas_limit \\ @min_gas_limit
      ) do
      context = %Validation.Context{
        parent_header: parent_header,
        homestead_block: homestead_block,
        initial_difficulty: initial_difficulty,
        minimum_difficulty: minimum_difficulty,
        difficulty_bound_divisor: difficulty_bound_divisor,
        gas_limit_bound_divisor: gas_limit_bound_divisor,
        min_gas_limit: min_gas_limit
      }
    Validation.validate(header, context)
  end

  @doc """
  Returns the total available gas left for all transactions in
  this block. This is the total gas limit minus the gas used
  in transactions.

  ## Examples

      iex> EthCore.Block.Header.available_gas(%EthCore.Block.Header{gas_limit: 50_000, gas_used: 30_000})
      20_000
  """
  @spec available_gas(t) :: EVM.Gas.t()
  def available_gas(header) do
    header.gas_limit - header.gas_used
  end
end
