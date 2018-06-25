defmodule Blockchain.Contract.MessageCall do
  @moduledoc """
  Represents a message call command,
  as defined in Section 8, Eq.(98) of the Yellow Paper.
  """

  alias Blockchain.Interface.{BlockInterface, AccountInterface}
  alias Block.Header
  alias Blockchain.Account
  alias EVM.SubState

  # σ
  defstruct state: %{},
            # s
            sender: <<>>,
            # o
            originator: <<>>,
            recipient: <<>>,
            contract: <<>>,
            # g
            available_gas: 0,
            # p
            gas_price: 0,
            value: 0,
            apparent_value: 0,
            # d
            data: <<>>,
            # e
            stack_depth: 0,
            block_header: nil

  @type t :: %__MODULE__{
          state: EVM.state(),
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
          block_header: Header.t()
        }

  @doc """
  Executes a message call to a contract,
  defined in Section 8 Eq.(99) of the Yellow Paper as Θ.

  We are also inlining Eq.(105).

  TODO: Determine whether or not we should be passing in the block header directly.
  TODO: Add serious (less trivial) test cases in `contract_test.exs`

  """
  @spec execute(t()) :: {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  def execute(params) do
    fun = get_fun(params.recipient)

    # Note, this could fail if machine code is not in state
    {:ok, machine_code} = Account.get_machine_code(params.state, params.contract)

    # Initiates message call by transfering balance from sender to receiver.
    # This covers Eq.(101), Eq.(102), Eq.(103) and Eq.(104) of the Yellow Paper.
    # TODO: make copy of original state or use cache for making changes
    state = Account.transfer!(params.state, params.sender, params.recipient, params.value)

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
      block_interface: BlockInterface.new(params.block_header, state.db),
      account_interface: AccountInterface.new(state)
    }

    {gas, sub_state, exec_env, output} = fun.(params.available_gas, exec_env)

    # From the Yellow Paper:
    # if the execution halts in an exceptional fashion
    # (i.e.  due to an exhausted gas supply, stack underflow, in-
    # valid jump destination or invalid instruction), then no gas
    # is refunded to the caller and the state is reverted to the
    # point immediately prior to balance transfe
    if output == :failed do
      {params.state, 0, SubState.empty(), :failed}
    else
      {exec_env.account_interface.state, gas, sub_state, output}
    end
  end

  @doc """
  Returns the given function to run given a contract address.
  This covers selecting a pre-defined function if specified.
  This is defined in Eq.(119) of the Yellow Paper.

  ## Examples

      iex> Blockchain.Contract.MessageCall.get_fun(<<1::160>>)
      &EVM.Builtin.run_ecrec/2

      iex> Blockchain.Contract.MessageCall.get_fun(<<2::160>>)
      &EVM.Builtin.run_sha256/2

      iex> Blockchain.Contract.MessageCall.get_fun(<<3::160>>)
      &EVM.Builtin.run_rip160/2

      iex> Blockchain.Contract.MessageCall.get_fun(<<4::160>>)
      &EVM.Builtin.run_id/2

      iex> Blockchain.Contract.MessageCall.get_fun(<<5::160>>)
      &EVM.VM.run/2

      iex> Blockchain.Contract.MessageCall.get_fun(<<6::160>>)
      &EVM.VM.run/2
  """
  @spec get_fun(EVM.address()) ::
          (EVM.Gas.t(), EVM.ExecEnv.t() ->
             {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()})
  def get_fun(recipient) do
    case :binary.decode_unsigned(recipient) do
      1 -> &EVM.Builtin.run_ecrec/2
      2 -> &EVM.Builtin.run_sha256/2
      3 -> &EVM.Builtin.run_rip160/2
      4 -> &EVM.Builtin.run_id/2
      _ -> &EVM.VM.run/2
    end
  end
end
