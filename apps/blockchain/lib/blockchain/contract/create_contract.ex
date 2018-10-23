defmodule Blockchain.Contract.CreateContract do
  @moduledoc """
  Represents a contract creation command,
  as defined in Section 7, Eq.(76) of the Yellow Paper.
  """

  alias Block.Header
  alias Blockchain.{Account, BlockHeaderInfo}
  alias Blockchain.Account.Repo
  alias EVM.{Gas, SubState}

  defstruct account_repo: %Repo{},
            sender: <<>>,
            originator: <<>>,
            available_gas: 0,
            gas_price: 0,
            endowment: 0,
            init_code: <<>>,
            stack_depth: 0,
            block_header: nil,
            new_account_address: nil,
            config: EVM.Configuration.Frontier.new()

  @typedoc """
  Yellow Paper Terms:

  - σ: state,
  - s: sender,
  - o: originator,
  - g: available_gas,
  - p: gas_price,
  - v: endowment,
  - i: init_code,
  - e: stack_depth
  """
  @type t :: %__MODULE__{
          account_repo: Repo.t(),
          sender: EVM.address(),
          originator: EVM.address(),
          available_gas: EVM.Gas.t(),
          gas_price: EVM.Gas.gas_price(),
          endowment: EVM.Wei.t(),
          init_code: EVM.MachineCode.t(),
          stack_depth: integer(),
          block_header: Header.t(),
          new_account_address: nil | EVM.address(),
          config: EVM.Configuration.t()
        }

  @spec execute(t()) :: {:ok | :error, {Repo.t(), EVM.Gas.t(), EVM.SubState.t(), binary() | <<>>}}
  def execute(params) do
    original_account_repo = params.account_repo
    contract_address = new_account_address(params)
    account = Repo.account(original_account_repo, contract_address)

    if is_nil(account) || Account.uninitialized_contract?(account) do
      result = {rem_gas, _, _, output} = create(params, contract_address)

      # From the Yellow Paper:
      # if the execution halts in an exceptional fashion
      # (i.e.  due to an exhausted gas supply, stack underflow, in-
      # valid jump destination or invalid instruction), then no gas
      # is refunded to the caller and the state is reverted to the
      # point immediately prior to balance transfer.
      #
      case output do
        :failed -> error(original_account_repo)
        {:revert, output} -> {:error, {original_account_repo, rem_gas, SubState.empty(), output}}
        _ -> finalize(result, params, contract_address)
      end
    else
      if account_will_collide?(account) do
        error(original_account_repo)
      else
        {:ok, {original_account_repo, 0, SubState.empty(), <<>>}}
      end
    end
  end

  @spec increment_nonce_of_touched_account(
          Repo.t(),
          EVM.Configuration.t(),
          EVM.address()
        ) :: Repo.t()
  defp increment_nonce_of_touched_account(account_repo, config, address) do
    if EVM.Configuration.for(config).increment_nonce_on_create?(config) do
      Repo.increment_account_nonce(account_repo, address)
    else
      account_repo
    end
  end

  @spec account_will_collide?(Account.t()) :: boolean()
  defp account_will_collide?(account) do
    account.nonce > 0 || !Account.is_simple_account?(account)
  end

  @spec error(Repo.t()) :: {:error, {Repo.t(), 0, SubState.t(), <<>>}}
  defp error(account_repo) do
    {:error, {account_repo, 0, SubState.empty(), <<>>}}
  end

  @spec create(t(), EVM.address()) ::
          {EVM.state(), EVM.Gas.t(), EVM.SubState.t(), EVM.VM.output()}
  defp create(params, address) do
    account_repo =
      params
      |> init_account(address)
      |> increment_nonce_of_touched_account(params.config, address)

    # Create an execution environment for a create contract call.
    # This is defined in Eq.(88), Eq.(89), Eq.(90), Eq.(91), Eq.(92),
    # Eq.(93), Eq.(94) and Eq.(95) of the Yellow Paper.
    exec_env = %EVM.ExecEnv{
      address: address,
      originator: params.originator,
      gas_price: params.gas_price,
      data: <<>>,
      sender: params.sender,
      value_in_wei: params.endowment,
      machine_code: params.init_code,
      stack_depth: params.stack_depth,
      block_header_info: BlockHeaderInfo.new(params.block_header, account_repo.state.db),
      account_repo: account_repo,
      config: params.config
    }

    EVM.VM.run(params.available_gas, exec_env)
  end

  @spec init_account(t, EVM.address()) :: Repo.t()
  defp init_account(params, address) do
    account = Repo.account(params.account_repo, address)

    account_repo =
      if is_nil(account) do
        Repo.reset_account(params.account_repo, address)
      else
        params.account_repo
      end
      |> Repo.set_empty_storage_root(address)

    Repo.transfer_wei!(account_repo, params.sender, address, params.endowment)
  end

  @spec finalize(
          {EVM.Gas.t(), EVM.SubState.t(), EVM.ExecEnv.t(), EVM.VM.output()},
          t(),
          EVM.address()
        ) :: {:ok | :error, {Repo.t(), EVM.Gas.t(), EVM.SubState.t(), binary() | <<>>}}
  defp finalize({remaining_gas, accrued_sub_state, exec_env, output}, params, address) do
    original_account_repo = params.account_repo
    contract_creation_cost = creation_cost(output)
    insufficient_gas = remaining_gas < contract_creation_cost

    cond do
      insufficient_gas &&
          EVM.Configuration.for(params.config).fail_contract_creation_lack_of_gas?(params.config) ->
        {:error, {original_account_repo, 0, SubState.empty(), <<>>}}

      EVM.Configuration.for(params.config).limit_contract_code_size?(
        params.config,
        byte_size(output)
      ) ->
        {:error, {original_account_repo, 0, SubState.empty(), <<>>}}

      true ->
        modified_account_repo = exec_env.account_repo

        resultant_gas =
          if insufficient_gas do
            remaining_gas
          else
            remaining_gas - contract_creation_cost
          end

        resultant_account_repo =
          if insufficient_gas do
            modified_account_repo
          else
            Repo.put_code(modified_account_repo, address, output)
          end

        sub_state = SubState.add_touched_account(accrued_sub_state, address)

        {:ok, {resultant_account_repo, resultant_gas, sub_state, <<>>}}
    end
  end

  # Returns the additional cost after creating a new contract.
  # This is defined as Eq.(96) of the Yellow Paper.
  @spec creation_cost(binary()) :: EVM.Wei.t()
  defp creation_cost(output) do
    data_size =
      output
      |> :binary.bin_to_list()
      |> Enum.count()

    data_size * Gas.codedeposit_cost()
  end

  defp new_account_address(params) do
    if params.new_account_address do
      params.new_account_address
    else
      sender_account = Repo.account(params.account_repo, params.sender)
      Account.Address.new(params.sender, sender_account.nonce)
    end
  end
end
