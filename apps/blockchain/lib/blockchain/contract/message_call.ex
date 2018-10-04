defmodule Blockchain.Contract.MessageCall do
  @moduledoc """
  Represents a message call command,
  as defined in Section 8, Eq.(98) of the Yellow Paper.
  """

  alias Blockchain.Interface.AccountInterface
  alias Blockchain.BlockHeaderInfo
  alias Block.Header
  alias EVM.SubState
  alias EVM.MessageCall

  defstruct account_interface: %AccountInterface{},
            sender: <<>>,
            originator: <<>>,
            recipient: <<>>,
            contract: <<>>,
            available_gas: 0,
            gas_price: 0,
            value: 0,
            apparent_value: 0,
            data: <<>>,
            stack_depth: 0,
            block_header: nil,
            config: EVM.Configuration.Frontier.new()

  @typedoc """
  Terms from the Yellow Paper:

  σ: state
  s: sender,
  o: originator,
  r: recipient,
  g: available_gas
  p: gas_price,
  v: value,
  v with overline: apparent_value,
  d: data,
  e: stack_depth
  """
  @type t :: %__MODULE__{
          account_interface: AccountInterface.t(),
          sender: EVM.address(),
          originator: EVM.address(),
          recipient: EVM.address(),
          contract: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          value: EVM.Wei.t(),
          apparent_value: EVM.Wei.t(),
          data: binary(),
          stack_depth: integer(),
          block_header: Header.t(),
          config: EVM.Configuration.t()
        }

  @doc """
  Executes a message call to a contract,
  defined in Section 8 Eq.(99) of the Yellow Paper as Θ.

  We are also inlining Eq.(105).

  TODO: Determine whether or not we should be passing in the block header directly.
  TODO: Add serious (less trivial) test cases in `contract_test.exs`
  """
  @spec execute(t()) ::
          {:ok | :error, {AccountInterface.t(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}}
  def execute(params) do
    run = MessageCall.get_run_function(params.recipient, params.config)

    # Note, this could fail if machine code is not in state
    {:ok, machine_code} = AccountInterface.machine_code(params.account_interface, params.contract)

    # Initiates message call by transfering balance from sender to receiver.
    # This covers Eq.(101), Eq.(102), Eq.(103) and Eq.(104) of the Yellow Paper.
    account_interface =
      AccountInterface.transfer_wei!(
        params.account_interface,
        params.sender,
        params.recipient,
        params.value
      )

    # Create an execution environment for a message call.
    # This is defined in Eq.(107), Eq.(108), Eq.(109), Eq.(110),
    # Eq.(111), Eq.(112), Eq.(113) and Eq.(114) of the Yellow Paper.
    exec_env = %EVM.ExecEnv{
      address: params.recipient,
      originator: params.originator,
      gas_price: params.gas_price,
      data: params.data,
      sender: params.sender,
      value_in_wei: params.apparent_value,
      machine_code: machine_code,
      stack_depth: params.stack_depth,
      block_header_info: BlockHeaderInfo.new(params.block_header, account_interface.state.db),
      account_interface: account_interface,
      config: params.config
    }

    {gas, sub_state, exec_env, output} = run.(params.available_gas, exec_env)
    sub_state = SubState.add_touched_account(sub_state, params.recipient)

    # From the Yellow Paper:
    # if the execution halts in an exceptional fashion
    # (i.e.  due to an exhausted gas supply, stack underflow, in-
    # valid jump destination or invalid instruction), then no gas
    # is refunded to the caller and the state is reverted to the
    # point immediately prior to balance transfer.
    case output do
      :failed ->
        {:error, {params.account_interface, 0, SubState.empty(), :failed}}

      {:revert, _output} ->
        {:error, {params.account_interface, gas, SubState.empty(), :failed}}

      _ ->
        {:ok, {exec_env.account_interface, gas, sub_state, output}}
    end
  end
end
