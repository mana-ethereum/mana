defmodule EVM.SubState do
  @moduledoc """
  Functions for handling the sub-state that exists only
  between operations in an execution for a contract.
  """

  alias EVM.{
    Operation,
    LogEntry,
    Refunds,
    ExecEnv,
    SubState,
    MachineState
  }

  defstruct selfdestruct_list: [],
            logs: [],
            refund: 0

  @type selfdestruct_list :: [EVM.address()]
  @type logs :: [LogEntry.t()]
  @type refund :: EVM.Wei.t()

  @type t :: %__MODULE__{
          selfdestruct_list: selfdestruct_list,
          logs: logs,
          refund: refund
        }

  @doc """
  Adds log entry to substate's log entry list.

  ## Examples

      iex> sub_state = %EVM.SubState{selfdestruct_list: [], logs: [], refund: 0}
      iex> sub_state |> EVM.SubState.add_log(0, [1, 10, 12], "adsfa")
      %EVM.SubState{
        logs: [
          %EVM.LogEntry{
            address: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
            data: "adsfa",
            topics: [1, 10, 12]
          }
        ],
        refund: 0,
        selfdestruct_list: []
      }
  """
  @spec add_log(t(), EVM.address(), Operation.stack_args(), binary()) :: t()
  def add_log(sub_state, address, topics, data) do
    log_entry = LogEntry.new(address, topics, data)

    new_logs = sub_state.logs ++ [log_entry]

    %{sub_state | logs: new_logs}
  end

  @doc """
  Adds refunds based on the  current instruction to the specified machine
  substate.

  ## Examples

      iex> account_interface = EVM.Interface.Mock.MockAccountInterface.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>   account_interface: account_interface,
      ...>   machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5, 4)
      iex> machine_state = %EVM.MachineState{gas: 10, stack: [5 , 0], program_counter: 0}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.SubState.add_refund(machine_state, sub_state, exec_env)
      %EVM.SubState{refund: 15000}
  """
  @spec add_refund(MachineState.t(), SubState.t(), ExecEnv.t()) :: SubState.t()
  def add_refund(machine_state, sub_state, exec_env) do
    refund = Refunds.refund(machine_state, sub_state, exec_env)

    %{sub_state | refund: sub_state.refund + refund}
  end
end
