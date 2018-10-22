defmodule Block.Header do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  For more information, see Section 4.3 of the Yellow Paper.
  """

  alias ExthCrypto.Hash.Keccak

  @empty_trie MerklePatriciaTree.Trie.empty_trie_root_hash()
  @empty_keccak [] |> ExRLP.encode() |> Keccak.kec()

  @frontier_difficulty_adjustment 13

  defstruct parent_hash: nil,
            ommers_hash: @empty_keccak,
            beneficiary: nil,
            state_root: @empty_trie,
            transactions_root: @empty_trie,
            receipts_root: @empty_trie,
            logs_bloom: <<0::2048>>,
            difficulty: nil,
            number: nil,
            gas_limit: 0,
            gas_used: 0,
            timestamp: nil,
            extra_data: <<>>,
            mix_hash: <<0::256>>,
            nonce: <<0::64>>

  @typedoc """
  As defined in section 4.3 of Yellow Paper:

  * H_p P(B_H)H_r = parent_hash
  * H_o KEC(RLP(L∗H(B_U)))  = ommers_hash
  * H_c = beneficiary
  * H_r TRIE(LS(Π(σ, B))) = state_root
  * H_t TRIE({∀i < kBTk, i ∈ P : p(i, LT(B_T[i]))}) = transactions_root
  * H_e TRIE({∀i < kBRk, i ∈ P : p(i, LR(B_R[i]))}) = receipts_root
  * H_b bloom = logs_bloom
  * H_d = difficulty
  * H_i = number
  * H_l = gas_limit
  * H_g = gas_used
  * H_s = timestamp
  * H_x = extra_data
  * H_m = mix_hash
  * H_n = nonce
  """
  @type t :: %__MODULE__{
          parent_hash: EVM.hash(),
          ommers_hash: EVM.trie_root(),
          beneficiary: EVM.address() | nil,
          state_root: EVM.trie_root(),
          transactions_root: EVM.trie_root(),
          receipts_root: EVM.trie_root(),
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

  # Must be 32 bytes or fewer. See H_e in Eq.(37)
  @max_extra_data_bytes 32

  # Constant from Eq.(47)
  @gas_limit_bound_divisor 1024

  # Eq.(47)
  @min_gas_limit 125_000

  @dao_extra_data "dao-hard-fork"

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

  ## Examples

      iex> Block.Header.serialize(%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>})
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>]
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
  This effectively undoes the encoding defined in L_H Eq.(34) of the
  Yellow Paper.

  ## Examples

      iex> Block.Header.deserialize([<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>])
      %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
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

  ## Examples

      iex> %Block.Header{number: 5, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> |> Block.Header.hash()
      <<78, 28, 127, 10, 192, 253, 127, 239, 254, 179, 39, 34, 245, 44, 152, 98, 128, 71, 238, 155, 100, 161, 199, 71, 243, 223, 172, 191, 74, 99, 128, 63>>

      iex> %Block.Header{number: 0, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      ...> |> Block.Header.hash()
      <<218, 225, 46, 241, 196, 160, 136, 96, 109, 216, 73, 167, 92, 174, 91, 228, 85, 112, 234, 129, 99, 200, 158, 61, 223, 166, 165, 132, 187, 24, 142, 193>>
  """
  @spec hash(t) :: EVM.hash()
  def hash(header) do
    header
    |> serialize()
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  @doc """
  Returns true if the block header is valid.
  This defines Eq.(50) of the Yellow Paper,
  commonly referred to as V(H).

  ## Examples

      iex> Block.Header.validate(%Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000}, nil, 131_072)
      :valid

      iex> Block.Header.validate(%Block.Header{number: 0, difficulty: 5, gas_limit: 5}, nil, 15)
      {:invalid, [:invalid_difficulty, :invalid_gas_limit]}

      iex> Block.Header.validate(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_136)
      :valid

      iex> Block.Header.validate(%Block.Header{number: 1, difficulty: 131_000, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_100)
      {:invalid, [:invalid_difficulty]}

      iex> Block.Header.validate(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 45}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_136)
      {:invalid, [:child_timestamp_invalid]}

      iex> Block.Header.validate(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 300_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_136)
      {:invalid, [:invalid_gas_limit]}

      iex> Block.Header.validate(%Block.Header{number: 2, difficulty: 131_136, gas_limit: 200_000, timestamp: 65}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_136)
      {:invalid, [:child_number_invalid]}

      iex> Block.Header.validate(%Block.Header{number: 1, difficulty: 131_136, gas_limit: 200_000, timestamp: 65, extra_data: "0123456789012345678901234567890123456789"}, %Block.Header{number: 0, difficulty: 131_072, gas_limit: 200_000, timestamp: 55}, 131_136)
      {:invalid, [:extra_data_too_large]}
  """
  @spec validate(t, t | nil, integer(), integer(), integer()) :: :valid | {:invalid, [atom()]}
  def validate(
        header,
        parent_header,
        expected_difficulty,
        gas_limit_bound_divisor \\ @gas_limit_bound_divisor,
        min_gas_limit \\ @min_gas_limit,
        validate_dao_extra_data \\ false
      ) do
    parent_gas_limit = if parent_header, do: parent_header.gas_limit, else: nil

    errors =
      []
      |> extra_data_validity(header)
      |> check_child_number_validity(header, parent_header)
      |> check_child_timestamp_validity(header, parent_header)
      |> check_gas_limit_validity(
        header,
        parent_gas_limit,
        gas_limit_bound_divisor,
        min_gas_limit
      )
      |> check_gas_limit(header)
      |> check_difficulty_validity(header, expected_difficulty)
      |> check_extra_data_validity(header, validate_dao_extra_data)

    if errors == [], do: :valid, else: {:invalid, errors}
  end

  @doc """
  Returns the total available gas left for all transactions in
  this block. This is the total gas limit minus the gas used
  in transactions.

  ## Examples

      iex> Block.Header.available_gas(%Block.Header{gas_limit: 50_000, gas_used: 30_000})
      20_000
  """
  @spec available_gas(t) :: EVM.Gas.t()
  def available_gas(header) do
    header.gas_limit - header.gas_used
  end

  @doc """
  Calculates the difficulty of a new block header for Byzantium. This implements
  Eq.(41), Eq.(42), Eq.(43), Eq.(44), Eq.(45) and Eq.(46) of the Yellow Paper.

  ## Examples

      iex> Block.Header.get_byzantium_difficulty(
      ...>   %Block.Header{number: 1, timestamp: 1479642530},
      ...>   %Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576},
      ...>   3_000_000
      ...> )
      997_888
  """
  def get_byzantium_difficulty(
        header,
        parent_header,
        delay_factor,
        initial_difficulty \\ @initial_difficulty,
        minimum_difficulty \\ @minimum_difficulty,
        difficulty_bound_divisor \\ @difficulty_bound_divisor
      ) do
    if header.number == 0 do
      initial_difficulty
    else
      difficulty_delta =
        difficulty_x(parent_header.difficulty, difficulty_bound_divisor) *
          byzantium_difficulty_parameter(header, parent_header)

      next_difficulty =
        parent_header.difficulty + difficulty_delta + byzantium_difficulty_e(header, delay_factor)

      max(minimum_difficulty, next_difficulty)
    end
  end

  @doc """
  Calculates the difficulty of a new block header for Homestead. This implements
  Eq.(41), Eq.(42), Eq.(43), Eq.(44), Eq.(45) and Eq.(46) of the Yellow Paper.

  ## Examples

      iex> Block.Header.get_homestead_difficulty(
      ...>  %Block.Header{number: 3_000_001, timestamp: 66},
      ...>  %Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      ...> )
      268_735_456

      iex> Block.Header.get_homestead_difficulty(
      ...>  %Block.Header{number: 3_000_001, timestamp: 155},
      ...>  %Block.Header{number: 3_000_000, timestamp: 55, difficulty: 300_000}
      ...> )
      268_734_142
  """
  @spec get_homestead_difficulty(t, t | nil, integer(), integer(), integer()) :: integer()
  def get_homestead_difficulty(
        header,
        parent_header,
        initial_difficulty \\ @initial_difficulty,
        minimum_difficulty \\ @minimum_difficulty,
        difficulty_bound_divisor \\ @difficulty_bound_divisor
      ) do
    if header.number == 0 do
      initial_difficulty
    else
      difficulty_delta =
        difficulty_x(parent_header.difficulty, difficulty_bound_divisor) *
          homestead_difficulty_parameter(header, parent_header)

      next_difficulty = parent_header.difficulty + difficulty_delta + difficulty_e(header)

      max(minimum_difficulty, next_difficulty)
    end
  end

  @doc """
  Calculates the difficulty of a new block header for Frontier. This implements
  Eq.(41), Eq.(42), Eq.(43), Eq.(44), Eq.(45) and Eq.(46) of the Yellow Paper.

  ## Examples

      iex> Block.Header.get_frontier_difficulty(
      ...>   %Block.Header{number: 0, timestamp: 55},
      ...>   nil
      ...> )
      131_072

      iex> Block.Header.get_frontier_difficulty(
      ...>   %Block.Header{number: 1, timestamp: 1479642530},
      ...>   %Block.Header{number: 0, timestamp: 0, difficulty: 1_048_576}
      ...> )
      1_048_064

      iex> Block.Header.get_frontier_difficulty(
      ...>  %Block.Header{number: 33, timestamp: 66},
      ...>  %Block.Header{number: 32, timestamp: 55, difficulty: 300_000}
      ...> )
      300_146

      iex> Block.Header.get_frontier_difficulty(
      ...>  %Block.Header{number: 33, timestamp: 88},
      ...>  %Block.Header{number: 32, timestamp: 55, difficulty: 300_000}
      ...> )
      299_854
  """
  @spec get_frontier_difficulty(t, t | nil, integer(), integer(), integer()) :: integer()
  def get_frontier_difficulty(
        header,
        parent_header,
        initial_difficulty \\ @initial_difficulty,
        minimum_difficulty \\ @minimum_difficulty,
        difficulty_bound_divisor \\ @difficulty_bound_divisor
      ) do
    if header.number == 0 do
      initial_difficulty
    else
      difficulty_delta =
        difficulty_x(parent_header.difficulty, difficulty_bound_divisor) *
          delta_sign(header, parent_header)

      next_difficulty = parent_header.difficulty + difficulty_delta + difficulty_e(header)

      max(minimum_difficulty, next_difficulty)
    end
  end

  # Eq.(42) ς1 - Effectively decides if blocks are being mined too quicky or too slowly
  @spec delta_sign(t, t) :: integer()
  defp delta_sign(header, parent_header) do
    if header.timestamp < parent_header.timestamp + @frontier_difficulty_adjustment,
      do: 1,
      else: -1
  end

  # Eq.(43) ς2
  @spec homestead_difficulty_parameter(t, t) :: integer()
  defp homestead_difficulty_parameter(header, parent_header) do
    s = div(header.timestamp - parent_header.timestamp, 10)
    max(1 - s, -99)
  end

  @spec byzantium_difficulty_parameter(t, t) :: integer()
  defp byzantium_difficulty_parameter(header, parent_header) do
    s = div(header.timestamp - parent_header.timestamp, 9)
    y = if parent_header.ommers_hash == @empty_keccak, do: 1, else: 2
    max(y - s, -99)
  end

  # Eq.(41) x - Creates some multiplier for how much we should change difficulty based on previous difficulty
  @spec difficulty_x(integer(), integer()) :: integer()
  defp difficulty_x(parent_difficulty, difficulty_bound_divisor),
    do: div(parent_difficulty, difficulty_bound_divisor)

  # Eq.(46) H' - ε non negative
  @spec byzantium_difficulty_e(t, integer()) :: integer()
  defp byzantium_difficulty_e(header, delay_factor) do
    fake_block_number_to_delay_ice_age = max(header.number - delay_factor, 0)
    difficulty_exponent_calculation(fake_block_number_to_delay_ice_age)
  end

  # Eq.(44) ε - Adds a delta to ensure we're increasing difficulty over time
  @spec difficulty_e(t) :: integer()
  defp difficulty_e(header) do
    difficulty_exponent_calculation(header.number)
  end

  defp difficulty_exponent_calculation(block_number) do
    MathHelper.floor(:math.pow(2, div(block_number, 100_000) - 2))
  end

  @spec check_difficulty_validity([atom()], t, integer()) :: [atom()]
  defp check_difficulty_validity(
         errors,
         header,
         expected_difficulty
       ) do
    if header.difficulty == expected_difficulty do
      errors
    else
      [:invalid_difficulty | errors]
    end
  end

  def check_extra_data_validity(errors, _header, false), do: errors

  def check_extra_data_validity(errors, header, true) do
    if header.extra_data == @dao_extra_data do
      errors
    else
      [:invalid_extra_data | errors]
    end
  end

  # Eq.(52)
  @spec check_gas_limit([atom()], t) :: [atom()]
  defp check_gas_limit(errors, header) do
    if header.gas_used <= header.gas_limit do
      errors
    else
      [:exceeded_gas_limit | errors]
    end
  end

  # Eq.(53), Eq.(54) and Eq.(55)
  @spec check_gas_limit_validity([atom()], t, EVM.Gas.t(), EVM.Gas.t(), EVM.Gas.t()) :: [atom()]
  defp check_gas_limit_validity(
         errors,
         header,
         parent_gas_limit,
         gas_limit_bound_divisor,
         min_gas_limit
       ) do
    if is_gas_limit_valid?(
         header.gas_limit,
         parent_gas_limit,
         gas_limit_bound_divisor,
         min_gas_limit
       ) do
      errors
    else
      [:invalid_gas_limit | errors]
    end
  end

  # Eq.(56)
  @spec check_child_timestamp_validity([atom()], t, t | nil) :: [atom()]
  defp check_child_timestamp_validity(errors, header, parent_header) do
    if is_nil(parent_header) or header.timestamp > parent_header.timestamp do
      errors
    else
      [:child_timestamp_invalid | errors]
    end
  end

  # Eq.(57)
  @spec check_child_number_validity([atom()], t, t | nil) :: [atom()]
  defp check_child_number_validity(errors, header, parent_header) do
    if header.number == 0 or header.number == parent_header.number + 1 do
      errors
    else
      [:child_number_invalid | errors]
    end
  end

  @spec extra_data_validity([atom()], t) :: [atom()]
  defp extra_data_validity(errors, header) do
    if byte_size(header.extra_data) <= @max_extra_data_bytes do
      errors
    else
      [:extra_data_too_large | errors]
    end
  end

  @doc """
  Function to determine if the gas limit set is valid.
  The miner gets to specify a gas limit, so long as it's in range.
  This allows about a 0.1% change per block.

  This function directly implements Eq.(47).

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

      iex> Block.Header.is_gas_limit_valid?(1_000_000, 2_000_000, 1)
      true

      iex> Block.Header.is_gas_limit_valid?(1_000, nil, 1024, 500)
      true
  """
  @spec is_gas_limit_valid?(EVM.Gas.t(), EVM.Gas.t() | nil) :: boolean()
  def is_gas_limit_valid?(
        gas_limit,
        parent_gas_limit,
        gas_limit_bound_divisor \\ @gas_limit_bound_divisor,
        min_gas_limit \\ @min_gas_limit
      ) do
    if parent_gas_limit == nil do
      # It's not entirely clear from the Yellow Paper
      # whether a genesis block should have any limits
      # on gas limit, other than min gas limit.
      gas_limit >= min_gas_limit
    else
      max_delta = MathHelper.floor(parent_gas_limit / gas_limit_bound_divisor)

      gas_limit < parent_gas_limit + max_delta and gas_limit > parent_gas_limit - max_delta and
        gas_limit >= min_gas_limit
    end
  end

  @spec mined_by?(t, EVM.address()) :: boolean()
  def mined_by?(header, address), do: header.beneficiary == address
end
