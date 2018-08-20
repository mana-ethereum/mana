defmodule EVMRunner do
  @moduledoc """
  Allows you to run raw evm code.

  Eg.

  $ mix run apps/blockchain/scripts/evm_runner.ex --code 600360050160005260206000f3 --gas-limit 27

  10:11:11.929 [debug] Gas Remaining: 3

  10:11:11.936 [debug] Result: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8>>

  """
  require Logger
  alias EVM.{VM, ExecEnv}
  alias EVM.Interface.Mock.MockAccountInterface
  alias EVM.Interface.Mock.MockBlockInterface

  def run() do
    {
      args,
      _
    } = OptionParser.parse!(System.argv(),
                                               switches: [
                                                 code: :string,
                                                 address: :string,
                                                 originator: :string,
                                                 timestamp: :integer,
                                                 gas_limit: :integer,
                                               ])
    account_interface = MockAccountInterface.new()
    block_interface = MockBlockInterface.new(%{
      timestamp: Keyword.get(args, :timestamp, 0),
    })

    gas_limit = Keyword.get(args, :gas_limit, 2_000_000)
    code_hex = Keyword.get(args, :code, "")
    machine_code = Base.decode16!(code_hex, case: :mixed)
    address = args
      |> Keyword.get(:address, "")
      |> Base.decode16,
      originator = args
      |> Keyword.get(:originator, "")
      |> Base.decode16,

    exec_env = %ExecEnv{
      machine_code: machine_code,
      address: Keyword.get(args, :address, "") |> Base.decode16,
      originator: Keyword.get(args, :originator, "") |> Base.decode16,
      account_interface: account_interface,
      block_interface: block_interface,
    }

    {gas_remaining, _sub_state, _exec_env, result} = VM.run(gas_limit, exec_env)
    Logger.debug fn ->
      "Gas Remaining: #{gas_remaining}"
    end

    Logger.debug fn ->
      "Result: #{inspect result}"
    end
  end
end

EVMRunner.run()
