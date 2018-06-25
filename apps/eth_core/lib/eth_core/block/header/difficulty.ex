defmodule EthCore.Block.Header.Difficulty do
  @moduledoc """
  This module is responsible for difficulty calculation.
  """

  alias EthCore.Math
  alias EthCore.Block.Header

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

  @doc """
  Calculates the difficulty of a new block header.
  This implements Eq.(41-46) of the Yellow Paper.
  """
  @spec calc(Header.t(), Header.t() | nil) :: integer()
  def calc(
        header,
        parent_header,
        initial_difficulty \\ @initial_difficulty,
        minimum_difficulty \\ @minimum_difficulty,
        difficulty_bound_divisor \\ @difficulty_bound_divisor,
        homestead_block \\ @homestead_block
      ) do
    cond do
      header.number == 0 ->
        initial_difficulty

      header.number < homestead_block ->
        # Find the delta from parent block
        difficulty_delta =
          calc_x(parent_header.difficulty, difficulty_bound_divisor) *
            calc_s1(header, parent_header) + calc_e(header)

        # Add delta to parent block
        next_difficulty = parent_header.difficulty + difficulty_delta

        # Return next difficulty, capped at minimum
        max(minimum_difficulty, next_difficulty)

      true ->
        # Find the delta from parent block (note: we use difficulty_s2 since we're after Homestead)
        difficulty_delta =
          calc_x(parent_header.difficulty, difficulty_bound_divisor) *
            calc_s2(header, parent_header) + calc_e(header)

        # Add delta to parent's difficulty
        next_difficulty = parent_header.difficulty + difficulty_delta

        # Return next difficulty, capped at minimum
        max(minimum_difficulty, next_difficulty)
    end
  end

  # Eq.(42) ς1 - Effectively decides if blocks are being mined too quicky or too slower
  @spec calc_s1(Header.t(), Header.t()) :: integer()
  defp calc_s1(header, parent_header) do
    if header.timestamp < parent_header.timestamp + 13, do: 1, else: -1
  end

  # Eq.(44) ς2
  @spec calc_s2(Header.t(), Header.t()) :: integer()
  defp calc_s2(header, parent_header) do
    timestamp_delta = header.timestamp - parent_header.timestamp
    s = Math.floor(timestamp_delta / 10)
    max(1 - s, -99)
  end

  # Eq.(41) x - Creates some multiplier for how much we should change difficulty based on previous difficulty
  @spec calc_x(integer(), integer()) :: integer()
  defp calc_x(parent_difficulty, difficulty_bound_divisor),
    do: Math.floor(parent_difficulty / difficulty_bound_divisor)

  # Eq.(44) ε - Adds a delta to ensure we're increasing difficulty over time
  @spec calc_e(Header.t()) :: integer()
  defp calc_e(header) do
    power = Math.floor(header.number / 100_000) - 2
    Math.floor(:math.pow(2, power))
  end
end
