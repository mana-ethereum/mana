defmodule EVM.Builtin do
  @moduledoc """
  Implements the built-in functions as defined in Appendix E
  of the Yellow Paper. These are contract functions that
  natively exist in Ethereum.
  """

  def run_ecrec(_state, _gas, _exec_env), do: nil
  def run_sha256(_state, _gas, _exec_env), do: nil
  def run_rip160(_state, _gas, _exec_env), do: nil
  def run_id(_state, _gas, _exec_env), do: nil
end
