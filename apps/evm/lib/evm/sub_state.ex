defmodule EVM.SubState do
  @moduledoc """
  Functions for handling the sub-state that exists only
  between operations in an execution for a contract.
  """

  alias EVM.{Operation, LogEntry}

  defstruct suicide_list: [],
            logs: [],
            refund: 0

  @type suicide_list :: [EVM.address()]
  @type logs :: [LogEntry.t()]
  @type refund :: EVM.Wei.t()

  @type t :: %__MODULE__{
          suicide_list: suicide_list,
          logs: logs,
          refund: refund
        }

  @doc """
  Adds log entry to substate's log entry list.

  ## Examples

      iex> sub_state = %EVM.SubState{suicide_list: [], logs: [], refund: 0}
      iex> sub_state |> EVM.SubState.add_log(<<0::160>>, [1, 10, 12], "adsfa")
      %EVM.SubState{
        logs: [
          %EVM.LogEntry{
            address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
            data: "adsfa",
            topics: [1, 10, 12]
          }
        ],
        refund: 0,
        suicide_list: []
      }
  """
  @spec add_log(t(), EVM.address(), Operation.stack_args(), binary()) :: t()
  def add_log(sub_state, address, topics, data) do
    log_entry = LogEntry.new(address, topics, data)

    new_logs = sub_state.logs ++ [log_entry]

    %{sub_state | logs: new_logs}
  end
end
