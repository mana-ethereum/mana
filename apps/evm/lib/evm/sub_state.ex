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
    MachineState,
    Refunds
  }

  defstruct selfdestruct_list: [],
            touched_accounts: [],
            logs: [],
            refund: 0

  @type address_list :: [EVM.address()]
  @type logs :: [LogEntry.t()]
  @type refund :: EVM.Wei.t()

  @type t :: %__MODULE__{
          selfdestruct_list: address_list,
          touched_accounts: address_list,
          logs: logs,
          refund: refund
        }

  @doc """
  Returns the canonical empty sub-state.
  """
  def empty(), do: %__MODULE__{}

  @doc """
  Checks whether the given `sub_state` is empty.
  """
  def empty?(sub_state), do: %{sub_state | touched_accounts: []} == empty()

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
            topics: [
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10>>,
              <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12>>
            ]
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

      iex> account_repo = EVM.Mock.MockAccountRepo.new()
      iex> machine_code = <<EVM.Operation.metadata(:sstore).id>>
      iex> exec_env = %EVM.ExecEnv{
      ...>   account_repo: account_repo,
      ...>   machine_code: machine_code,
      ...> } |> EVM.ExecEnv.put_storage(5, 4)
      iex> machine_state = %EVM.MachineState{gas: 10, stack: [5 , 0], program_counter: 0}
      iex> sub_state = %EVM.SubState{}
      iex> EVM.SubState.add_refund(machine_state, sub_state, exec_env)
      %EVM.SubState{refund: 15000}
  """
  @spec add_refund(MachineState.t(), t(), ExecEnv.t()) :: t()
  def add_refund(machine_state, sub_state, exec_env) do
    refund = Refunds.refund(machine_state, sub_state, exec_env)

    %{sub_state | refund: sub_state.refund + refund}
  end

  @doc """
  Merges two SubState structs.

  ## Examples

      iex> substate1 = %EVM.SubState{refund: 5, logs: [1], selfdestruct_list: [5]}
      iex> substate2 = %EVM.SubState{refund: 5, logs: [5], selfdestruct_list: [1]}
      iex> EVM.SubState.merge(substate1, substate2)
      %EVM.SubState{refund: 10, logs: [1, 5], selfdestruct_list: [5, 1]}
  """

  @spec merge(t(), t()) :: t()
  def merge(sub_state1, sub_state2) do
    selfdestruct_list = sub_state1.selfdestruct_list ++ sub_state2.selfdestruct_list
    dedup_selfdestruct_list = Enum.dedup(selfdestruct_list)
    logs = sub_state1.logs ++ sub_state2.logs

    refund =
      sub_state1.refund + sub_state2.refund -
        (Enum.count(selfdestruct_list) - Enum.count(dedup_selfdestruct_list)) *
          Refunds.selfdestruct_refund()

    touched_accounts = Enum.dedup(sub_state1.touched_accounts ++ sub_state2.touched_accounts)

    %__MODULE__{
      refund: refund,
      selfdestruct_list: dedup_selfdestruct_list,
      touched_accounts: touched_accounts,
      logs: logs
    }
  end

  @doc """
  Marks an account for later destruction.

  ## Examples

      iex> sub_state = %EVM.SubState{}
      iex> address = <<0x01::160>>
      iex> EVM.SubState.mark_account_for_destruction(sub_state, address)
      %EVM.SubState{selfdestruct_list: [<<0x01::160>>]}
  """
  def mark_account_for_destruction(sub_state, account_address) do
    %{sub_state | selfdestruct_list: sub_state.selfdestruct_list ++ [account_address]}
  end

  def add_touched_account(sub_state, address) do
    %{sub_state | touched_accounts: sub_state.touched_accounts ++ [address]}
  end
end
