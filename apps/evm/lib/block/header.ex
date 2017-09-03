defmodule Block.Header do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  """

  # The start of the Homestead block, as defined in Eq.(13) of the Yellow Paper (N_H)
  @homestead 1_150_000
  @empty_trie MerklePatriciaTree.Trie.empty_trie()

  defstruct [
    parent_hash: <<>>,               # Hp P(BH)Hr
    ommers_hash: @empty_trie,        # Ho KEC(RLP(L∗H(BU)))
    beneficiary: <<>>,               # Hc
    state_root: @empty_trie,         # Hr TRIE(LS(Π(σ, B)))
    transactions_root: @empty_trie,  # Ht TRIE({∀i < kBTk, i ∈ P : p(i, LT (BT[i]))})
    receipts_root: @empty_trie,      # He TRIE({∀i < kBRk, i ∈ P : p(i, LR(BR[i]))})
    logs_bloom: <<>>,                # Hb bloom
    difficulty: nil,                 # Hd
    number: nil,                     # Hi
    gas_limit: 0,                    # Hl
    gas_used: 0,                     # Hg
    timestamp: nil,                  # Hs
    extra_data: <<>>,                # Hx
    mix_hash: nil,                   # Hm
    nonce: nil,                      # Hn
  ]

  # As defined in Eq.(35)
  @type t :: %__MODULE__{
    parent_hash: EVM.hash | <<>>,
    ommers_hash: EVM.trie_root,
    beneficiary: EVM.address | <<>>,
    state_root: EVM.trie_root,
    transactions_root: EVM.trie_root,
    receipts_root: EVM.trie_root,
    logs_bloom: binary(), # TODO
    difficulty: integer() | nil,
    number: integer() | nil,
    gas_limit: EVM.val,
    gas_used: EVM.val,
    timestamp: EVM.timestamp | nil,
    extra_data: binary(),
    mix_hash: EVM.hash | nil,
    nonce: <<_::64>> | nil, # TODO: 64-bit hash?
  }

  @initial_difficulty 131_072 # d_0 from Eq.(40)
  @max_extra_data_bytes 32 # Eq.(58)
  @min_gas_limit 125_000 # Eq.(47)

  @doc "Returns the block that defines the start of Homestead"
  @spec homestead() :: integer()
  def homestead, do: @homestead

  @doc """
  This functions encode a header into a value that can
  be RLP encoded. This is defined as L_H Eq.(32) in the Yellow Paper.

  ## Examples

      iex> Block.Header.serialize(%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>})
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(h) do
    [
      h.parent_hash,
      h.ommers_hash,
      h.beneficiary,
      h.state_root,
      h.transactions_root,
      h.receipts_root,
      h.logs_bloom,
      h.difficulty,
      h.number,
      h.gas_limit,
      h.gas_used,
      h.timestamp,
      h.extra_data,
      h.mix_hash,
      h.nonce
    ]
  end

  @doc """
  Deserializes a block header from an RLP encodable structure.
  This effectively undoes the encoding defined in L_H Eq.(32) of the
  Yellow Paper.

  ## Examples

      iex> Block.Header.deserialize([<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>])
      %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
  """
  @spec deserialize(ExRLP.t) :: t
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
      nonce: nonce,
    }
  end

  @doc """
  Returns true if a given block is before the
  Homestead block.

  ## Examples

      iex> Block.Header.is_before_homestead?(%Block.Header{number: 5})
      true

      iex> Block.Header.is_before_homestead?(%Block.Header{number: 5_000_000})
      false

      iex> Block.Header.is_before_homestead?(%Block.Header{number: 1_150_000})
      false
  """
  @spec is_before_homestead?(t) :: boolean()
  def is_before_homestead?(h) do
    h.number < @homestead
  end

  @doc """
  Returns true if a given block is at or after the
  Homestead block.

  ## Examples

      iex> Block.Header.is_after_homestead?(%Block.Header{number: 5})
      false

      iex> Block.Header.is_after_homestead?(%Block.Header{number: 5_000_000})
      true

      iex> Block.Header.is_after_homestead?(%Block.Header{number: 1_150_000})
      true
  """
  @spec is_after_homestead?(t) :: boolean()
  def is_after_homestead?(h), do: not is_before_homestead?(h)

  @doc """
  Returns true if the block header is valid. This defines
  Eq.(50), Eq.(51), Eq.(52), Eq.(53), Eq.(54), Eq.(55),
  Eq.(56), Eq.(57) and Eq.(58) of the Yellow Paper, commonly
  referred to as V(H).

  # TODO: Implement and add examples
  # TODO: Add proof of work check

  ## Examples

      iex> Block.Header.is_valid?(%Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000}, nil)
      :valid

      iex> Block.Header.is_valid?(%Block.Header{number: 0, difficulty: 5, gas_limit: 5}, nil, true)
      {:invalid, [:invalid_difficulty, :invalid_gas_limit]}

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      :valid

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_000, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      :valid

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_000, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, true)
      {:invalid, [:invalid_difficulty]}

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 45}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:child_timestamp_invalid]}

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 300_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:invalid_gas_limit]}

      iex> Block.Header.is_valid?(%Block.Header{number: 2, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:child_number_invalid]}

      iex> Block.Header.is_valid?(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65, extra_data: "0123456789012345678901234567890123456789"}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55})
      {:invalid, [:extra_data_too_large]}
  """
  @spec is_valid?(t, t | nil, boolean()) :: :valid | {:invalid, [atom()]}
  def is_valid?(header, parent_header, enforce_difficulty \\ false) do
    parent_gas_limit = if parent_header, do: parent_header.gas_limit, else: nil

    errors = [] ++
      (if not enforce_difficulty or header.difficulty == get_difficulty(header, parent_header), do: [], else: [:invalid_difficulty]) ++ # Eq.(51)
      (if header.gas_used <= header.gas_limit, do: [], else: [:exceeded_gas_limit]) ++ # Eq.(52)
      (if is_gas_limit_valid?(header.gas_limit, parent_gas_limit), do: [], else: [:invalid_gas_limit]) ++ # Eq.(53), Eq.(54) and Eq.(55)
      (if is_nil(parent_header) or header.timestamp > parent_header.timestamp, do: [], else: [:child_timestamp_invalid]) ++ # Eq.(56)
      (if header.number == 0 or header.number == parent_header.number + 1, do: [], else: [:child_number_invalid]) ++ # Eq.(57)
      (if byte_size(header.extra_data) <= @max_extra_data_bytes, do: [], else: [:extra_data_too_large])

    case errors do
      [] -> :valid
      _ -> {:invalid, errors}
    end
  end

  @doc """
  Returns the total available gas left for all transactions in
  this block. This is the total gas limit minus the gas used
  in transactions.

  ## Examples

      iex> Block.Header.available_gas(%Block.Header{gas_limit: 50_000, gas_used: 30_000})
      20_000
  """
  @spec available_gas(t) :: EVM.Gas.t
  def available_gas(header) do
    header.gas_limit - header.gas_used
  end

  @doc """
  Calculates the difficulty of a new block header. This implements Eq.(39),
  Eq.(40), Eq.(41), Eq.(42), Eq.(43) and Eq.(44) of the Yellow Paper.

  # TODO: Validate these results

  ## Examples

      iex> Block.Header.get_difficulty(
      ...>   %Block.Header{number: 0, timestamp: 55},
      ...>   nil
      ...> )
      131_072

      iex> Block.Header.get_difficulty(
      ...>   %Block.Header{number: 1, timestamp: 1479642530},
      ...>   %Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}
      ...> )
      1_048_064

      iex> Block.Header.get_difficulty(
      ...>  %Block.Header{number: 33, timestamp: 66},
      ...>  %Block.Header{number: 32, timestamp: 55, difficulty: 300_000}
      ...> )
      300_146

      iex> Block.Header.get_difficulty(
      ...>  %Block.Header{number: 33, timestamp: 88},
      ...>  %Block.Header{number: 32, timestamp: 55, difficulty: 300_000}
      ...> )
      299_854

      # TODO: Is this right? These numbers are quite a jump
      iex> Block.Header.get_difficulty(
      ...>  %Block.Header{number: 3_000_001, timestamp: 66},
      ...>  %Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      ...> )
      268_735_456

      iex> Block.Header.get_difficulty(
      ...>  %Block.Header{number: 3_000_001, timestamp: 155},
      ...>  %Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      ...> )
      268_734_142
  """
  @spec get_difficulty(t, t | nil) :: integer()
  def get_difficulty(header, parent_header) do
    cond do
      header.number == 0 -> @initial_difficulty
      is_before_homestead?(header) -> max(@initial_difficulty, parent_header.difficulty + difficulty_x(parent_header.difficulty) * difficulty_s1(header, parent_header) + difficulty_e(header))
      true -> max(@initial_difficulty, parent_header.difficulty + difficulty_x(parent_header.difficulty) * difficulty_s2(header, parent_header) + difficulty_e(header))
    end
  end

  # Eq.(42) ς1
  @spec difficulty_s1(t, t) :: integer()
  defp difficulty_s1(header, parent_header) do
    if header.timestamp < ( parent_header.timestamp + 13 ), do: 1, else: -1
  end

  # Eq.(43) ς2
  @spec difficulty_s2(t, t) :: integer()
  defp difficulty_s2(header, parent_header) do
    s = MathHelper.floor( ( header.timestamp - parent_header.timestamp ) / 10 )
    max(1 - s, -99)
  end

  # Eq.(41) x
  @spec difficulty_x(integer()) :: integer()
  defp difficulty_x(parent_difficulty), do: MathHelper.floor(parent_difficulty / 2048)

  # Eq.(44) ε
  @spec difficulty_e(t) :: integer()
  defp difficulty_e(header) do
    MathHelper.floor(
      :math.pow(
        2,
        MathHelper.floor( header.number / 100_000 ) - 2
      )
    )
  end

  @doc """
  Function to determine if the gas limit set is valid. The miner gets to
  specify a gas limit, so long as it's in range. This allows about a 0.1% change
  per block.

  This function directly implements Eq.(45), Eq.(46) and Eq.(47).

  ## Examples

      iex> Block.Header.is_gas_limit_valid?(1_000_000, nil)
      true

      iex> Block.Header.is_gas_limit_valid?(1_000, nil)
      false

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 1_000_000)
      true

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 2_000_000)
      false

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 500_000)
      false

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 999_500)
      true

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 999_000)
      false
  """
  @spec is_gas_limit_valid?(EVM.Gas.t, EVM.Gas.t | nil) :: boolean()
  def is_gas_limit_valid?(gas_limit, parent_gas_limit) do
    if parent_gas_limit == nil do
      # It's not entirely clear from the Yellow Paper
      # whether a genesis block should have any limits
      # on gas limit, other than min gas limit.
      gas_limit > @min_gas_limit
    else
      max_delta = MathHelper.floor(parent_gas_limit / 1024)

      ( gas_limit < parent_gas_limit + max_delta ) and
      ( gas_limit > parent_gas_limit - max_delta ) and
      gas_limit > @min_gas_limit
    end
  end
end