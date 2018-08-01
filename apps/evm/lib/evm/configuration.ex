defprotocol EVM.Configuration do
  @moduledoc """
  Prototcol for defining hardfork configurations.
  """

  @type t :: module()

  @spec contract_creation_cost(t) :: integer()
  def contract_creation_cost(t)

  @spec has_delegate_call?(t) :: boolean()
  def has_delegate_call?(t)
end
