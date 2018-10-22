defmodule EVM.TestFactory do
  alias EVM.{ExecEnv, MachineState, MessageCall, SubState}
  alias EVM.Mock.MockAccountRepo

  @doc """
  Main function to interact with factory. This will
  call the corresponding factory, and it allows for nicer
  keyword arguments.

  ## Examples

    iex> build(:message_call, gas_price: 5)
    %MessagesCall{..., gas_price: 5}
  """
  def build(factory_sym, opts \\ []) do
    args = Enum.into(opts, %{})
    factory(factory_sym, args)
  end

  def factory(:message_call, opts) do
    defaults = %{
      current_machine_state: build(:machine_state),
      current_exec_env: build(:exec_env),
      current_sub_state: build(:sub_state),
      output_params: {0, 2},
      sender: <<0x10::160>>,
      originator: <<0x10::160>>,
      recipient: <<0x20::160>>,
      code_owner: <<0x20::160>>,
      gas_price: 1,
      value: 5,
      execution_value: 100,
      data: <<1, 2, 3>>,
      stack_depth: 0
    }

    args = Map.merge(defaults, opts)
    struct!(MessageCall, args)
  end

  def factory(:machine_state, opts) do
    defaults = %{gas: 0, stack: [], program_counter: 0}
    args = Map.merge(defaults, opts)
    struct!(MachineState, args)
  end

  def factory(:sub_state, _opts) do
    %SubState{}
  end

  def factory(:machine_code, opts) do
    default = [:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore]
    operations = Map.get(opts, :operations, default)
    assembly = operations ++ [:push1, 32, :push1, 0, :return]

    EVM.MachineCode.compile(assembly)
  end

  def factory(:mock_account_repo, opts) do
    default_accounts = %{
      <<0x10::160>> => %{balance: 10, code: <<>>},
      <<0x20::160>> => %{balance: 20, code: build(:machine_code)}
    }

    account_map = Map.get(opts, :account_map, default_accounts)

    MockAccountRepo.new(account_map)
  end

  def factory(:exec_env, opts) do
    defaults = %{
      account_repo: build(:mock_account_repo),
      address: <<0x10::160>>,
      originator: <<0x10::160>>,
      gas_price: 1,
      data: <<1, 2, 3>>,
      sender: <<0x10::160>>,
      value_in_wei: 5,
      machine_code: <<1, 2, 3>>,
      stack_depth: 0
    }

    args = Map.merge(defaults, opts)
    struct!(ExecEnv, args)
  end
end
