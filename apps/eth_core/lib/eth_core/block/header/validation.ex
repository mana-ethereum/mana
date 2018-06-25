defmodule EthCore.Block.Header.Validation do
  @moduledoc """
  This module is responsible for validation of a block header.
  """

  alias EthCore.Math
  alias EthCore.Block.Header
  alias EthCore.Block.Header.Difficulty

  defmodule Context do
    @moduledoc """
    Represents a block header validation context.
    """

    @type t :: %__MODULE__{
            parent_header: Header.t() | nil,
            homestead_block: integer(),
            initial_difficulty: integer(),
            minimum_difficulty: integer(),
            difficulty_bound_divisor: integer(),
            gas_limit_bound_divisor: integer(),
            min_gas_limit: integer()
          }

    @required_keys [
      :homestead_block,
      :initial_difficulty,
      :minimum_difficulty,
      :difficulty_bound_divisor,
      :gas_limit_bound_divisor,
      :min_gas_limit
    ]

    @enforce_keys @required_keys
    defstruct [:parent_header] ++ @required_keys
  end

  # Must be 32 bytes or fewer. See H_e in Eq.(37)
  @max_extra_data_bytes 32

  @spec validate(Header.t(), Context.t()) :: :valid | {:invalid, [atom()]}
  def validate(header, context) do
    errors =
      []
      |> validate_extra_data(header)
      |> validate_child_number(header, context.parent_header)
      |> validate_child_timestamp(header, context.parent_header)
      |> check_gas_limit_validity(header, context)
      |> check_gas_limit(header)
      |> validate_difficulty(header, context)

    if errors == [], do: :valid, else: {:invalid, errors}
  end

  # Eq.(51)
  @spec validate_difficulty([atom()], Header.t(), Context.t()) :: [atom()]
  defp validate_difficulty(errors, header, context) do
    if header.difficulty ==
         Difficulty.calc(
           header,
           context.parent_header,
           context.initial_difficulty,
           context.minimum_difficulty,
           context.difficulty_bound_divisor,
           context.homestead_block
         ) do
      errors
    else
      [:invalid_difficulty | errors]
    end
  end

  # Eq.(52)
  @spec check_gas_limit([atom()], Header.t()) :: [atom()]
  defp check_gas_limit(errors, header) do
    if header.gas_used <= header.gas_limit do
      errors
    else
      [:exceeded_gas_limit | errors]
    end
  end

  # Eq.(53), Eq.(54) and Eq.(55)
  @spec check_gas_limit_validity([atom()], Header.t(), Context.t()) :: [atom()]
  defp check_gas_limit_validity(errors, header, context) do
    parent_gas_limit = if context.parent_header, do: context.parent_header.gas_limit, else: nil

    if valid_gas_limit?(
         header.gas_limit,
         parent_gas_limit,
         context.gas_limit_bound_divisor,
         context.min_gas_limit
       ) do
      errors
    else
      [:invalid_gas_limit | errors]
    end
  end

  # Eq.(56)
  @spec validate_child_timestamp([atom()], Header.t(), Header.t() | nil) :: [atom()]
  defp validate_child_timestamp(errors, header, parent_header) do
    if is_nil(parent_header) or header.timestamp > parent_header.timestamp do
      errors
    else
      [:child_timestamp_invalid | errors]
    end
  end

  # Eq.(57)
  @spec validate_child_number([atom()], Header.t(), Header.t() | nil) :: [atom()]
  defp validate_child_number(errors, header, parent_header) do
    if header.number == 0 or header.number == parent_header.number + 1 do
      errors
    else
      [:child_number_invalid | errors]
    end
  end

  @spec validate_extra_data([atom()], Header.t()) :: [atom()]
  defp validate_extra_data(errors, header) do
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
  """
  @spec valid_gas_limit?(integer(), integer() | nil, integer(), integer()) :: boolean()
  def valid_gas_limit?(gas_limit, parent_gas_limit, gas_limit_bound_divisor, min_gas_limit) do
    if parent_gas_limit == nil do
      # It's not entirely clear from the Yellow Paper
      # whether a genesis block should have any limits
      # on gas limit, other than min gas limit.
      gas_limit > min_gas_limit
    else
      max_delta = Math.floor(parent_gas_limit / gas_limit_bound_divisor)

      gas_limit < parent_gas_limit + max_delta and gas_limit > parent_gas_limit - max_delta and
        gas_limit > min_gas_limit
    end
  end
end
