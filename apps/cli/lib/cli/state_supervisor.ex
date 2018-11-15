defmodule CLI.StateSupervisor do
  use Supervisor
  alias CLI.State
  @moduledoc """
  Supervising CLI State and creating the ETS table that would hold chain changes for JSONRPC.
  """
  def start_link(chain) do
    Supervisor.start_link(__MODULE__, chain)
  end

  def init(chain) do
    :cli = :ets.new(:cli, [:set, :public, :named_table])
    children = [worker(State, [chain])]

    supervise(children, strategy: :one_for_one)
  end
end
