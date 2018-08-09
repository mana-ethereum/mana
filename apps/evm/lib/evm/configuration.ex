defprotocol EVM.Configuration do
  @moduledoc """
  Protocol for defining hardfork configurations.
  """

  @type t :: module()

  # EIP2
  @spec contract_creation_cost(t) :: integer()
  def contract_creation_cost(t)

  # EIP2
  @spec fail_contract_creation_lack_of_gas?(t) :: boolean()
  def fail_contract_creation_lack_of_gas?(t)

  # EIP7
  @spec has_delegate_call?(t) :: boolean()
  def has_delegate_call?(t)

  # EIP150
  @spec extcodesize_cost(t) :: integer()
  def extcodesize_cost(t)

  # EIP150
  @spec extcodecopy_cost(t) :: integer()
  def extcodecopy_cost(t)

  # EIP150
  @spec balance_cost(t) :: integer()
  def balance_cost(t)

  # EIP150
  @spec sload_cost(t) :: integer()
  def sload_cost(t)

  # EIP150
  @spec call_cost(t) :: integer()
  def call_cost(t)

  # EIP150
  @spec selfdestruct_cost(t, keyword()) :: integer()
  def selfdestruct_cost(t, params \\ [])

  # EIP150
  @spec fail_nested_operation_lack_of_gas?(t) :: boolean()
  def fail_nested_operation_lack_of_gas?(t)
end
