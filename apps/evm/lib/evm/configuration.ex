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
end
