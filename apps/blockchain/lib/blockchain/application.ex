defmodule Blockchain.Application do
  @moduledoc false

  use Application
  require Logger
  alias EVM.Debugger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    _ =
      if breakpoint_address_hex = System.get_env("BREAKPOINT") do
        case Base.decode16(breakpoint_address_hex, case: :mixed) do
          {:ok, breakpoint_address} ->
            Debugger.enable()
            id = Debugger.break_on(address: breakpoint_address)

            :ok =
              Logger.warn(
                "Debugger has been enabled. Set breakpoint ##{id} on contract address 0x#{
                  breakpoint_address_hex
                }."
              )

          :error ->
            _ = Logger.error("Invalid breakpoint address: #{breakpoint_address_hex}")
        end
      end

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Blockchain.Worker.start_link(arg1, arg2, arg3)
      # worker(Blockchain.Worker, [arg1, arg2, arg3]),
    ]

    opts = [strategy: :one_for_one, name: Blockchain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
