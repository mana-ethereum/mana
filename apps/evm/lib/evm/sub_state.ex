defmodule EVM.SubState do
  @moduledoc """
  Functions for handling the sub-state that exists only
  between operations in an execution for a contract.
  """

  defstruct suicide_list: [],
            logs: <<>>,
            refund: 0

  @type suicide_list :: [EVM.address()]
  @type logs :: binary()
  @type refund :: EVM.Wei.t()

  @type t :: %__MODULE__{
          suicide_list: suicide_list,
          logs: logs,
          refund: refund
        }
end
