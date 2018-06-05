defmodule EVM.Operation.SystemTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.System

  alias EVM.{ExecEnv, Address, Operation}
  alias EVM.Interface.Mock.MockAccountInterface

  describe "selfdestruct/2" do
    test "transfers wei to refund account" do
      selfdestruct_address = 0x0000000000000000000000000000000000000001
      refund_address = 0x0000000000000000000000000000000000000002
      account_map = %{selfdestruct_address => %{balance: 5_000, nonce: 5}}
      account_interface = MockAccountInterface.new(account_map)
      exec_env = %ExecEnv{address: selfdestruct_address, account_interface: account_interface}
      vm_opts = %{stack: [], exec_env: exec_env}
      new_exec_env = Operation.System.selfdestruct([refund_address], vm_opts)[:exec_env]
      accounts = new_exec_env.account_interface.account_map

      expected_refund_account = %{balance: 5000, code: <<>>, nonce: 0, storage: %{}}
      assert Map.get(accounts, Address.new(refund_address)) == expected_refund_account
      assert Map.get(accounts, selfdestruct_address) == nil
    end
  end
end
