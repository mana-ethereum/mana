defmodule EVM.ExecEnv do
  alias EVM.AccountRepo
  alias EVM.{BlockHeaderInfo, Configuration, MachineCode}

  @moduledoc """
  Stores information about the execution environment which led
  to this EVM being called. This is, for instance, the sender of
  a payment or message to a contract, or a sub-contract call.

  We've added our interfaces for interacting with contracts
  and accounts to this struct as well.

  This generally relates to `I` in the Yellow Paper, defined in Section 9.3.
  """

  defstruct address: nil,
            originator: nil,
            gas_price: nil,
            data: nil,
            sender: nil,
            value_in_wei: nil,
            machine_code: <<>>,
            valid_jump_destinations: [],
            stack_depth: 0,
            account_repo: nil,
            block_header_info: nil,
            config: Configuration.Frontier.new(),
            static: false

  @typedoc """
  Terms from Yellow Paper:

  - I_a: address
  - I_o: originator
  - I_p: gas_price
  - I_d: data
  - I_s: sender
  - I_v: value_in_wei
  - I_b: machine_code
  - I_e: stack_depth
  - I_H (via a behaviour): block_header info
  """
  @type t :: %__MODULE__{
          address: EVM.address() | nil,
          originator: EVM.address() | nil,
          gas_price: EVM.Gas.gas_price() | nil,
          data: binary() | nil,
          sender: EVM.address() | nil,
          value_in_wei: EVM.Wei.t() | nil,
          machine_code: EVM.MachineCode.t() | nil,
          valid_jump_destinations: list(non_neg_integer()) | [],
          stack_depth: integer(),
          block_header_info: BlockHeaderInfo.t(),
          account_repo: AccountRepo.t() | nil,
          config: Configuration.t(),
          static: boolean()
        }

  @doc """
  Sets valid_jump_destinations

  #
  ## Examples

      iex> EVM.ExecEnv.set_valid_jump_destinations(%EVM.ExecEnv{})
      %EVM.ExecEnv{valid_jump_destinations: []}

      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :jumpdest, :add, :return, :jumpdest, :stop])
      iex> EVM.ExecEnv.set_valid_jump_destinations(%EVM.ExecEnv{machine_code: machine_code})
      ...> |> Map.get(:valid_jump_destinations)
      [4, 7]

  """
  def set_valid_jump_destinations(exec_env) do
    valid_jump_destinations =
      MachineCode.valid_jump_destinations(Map.get(exec_env, :machine_code))

    exec_env
    |> Map.put(:valid_jump_destinations, valid_jump_destinations)
  end

  @spec put_storage(t(), integer(), integer()) :: t()
  def put_storage(
        exec_env = %{account_repo: account_repo, address: address},
        key,
        value
      ) do
    account_repo = AccountRepo.repo(account_repo).put_storage(account_repo, address, key, value)

    Map.put(exec_env, :account_repo, account_repo)
  end

  @spec storage(t(), integer()) :: {t(), atom() | {:ok, integer()}}
  def storage(exec_env = %{account_repo: account_repo, address: address}, key) do
    {updated_repo, value} = AccountRepo.repo(account_repo).storage(account_repo, address, key)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, value}
  end

  @spec initial_storage(t(), integer()) :: {t(), atom() | {:ok, integer()}}
  def initial_storage(exec_env = %{account_repo: account_repo, address: address}, key) do
    {updated_repo, value} =
      AccountRepo.repo(account_repo).initial_storage(account_repo, address, key)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, value}
  end

  @spec balance(t(), EVM.Address.t()) :: {t(), EVM.Wei.t() | nil}
  def balance(exec_env = %{account_repo: account_repo}, address) do
    {updated_repo, balance} =
      AccountRepo.repo(account_repo).account_balance(account_repo, address)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, balance}
  end

  @spec remove_storage(t(), integer()) :: t()
  def remove_storage(exec_env = %{account_repo: account_repo, address: address}, key) do
    account_repo = AccountRepo.repo(account_repo).remove_storage(account_repo, address, key)

    Map.put(exec_env, :account_repo, account_repo)
  end

  @spec clear_account_balance(t()) :: t()
  def clear_account_balance(exec_env = %{account_repo: account_repo, address: address}) do
    account_repo = AccountRepo.repo(account_repo).clear_balance(account_repo, address)

    Map.put(exec_env, :account_repo, account_repo)
  end

  @spec transfer_balance_to(t(), EVM.Address.t()) :: t()
  def transfer_balance_to(exec_env, to) do
    %{account_repo: account_repo, address: address} = exec_env

    {updated_repo, balance} =
      AccountRepo.repo(account_repo).account_balance(account_repo, address)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    transfer_wei_to(updated_exec_env, to, balance)
  end

  @spec transfer_wei_to(t(), EVM.Address.t(), integer()) :: t()
  def transfer_wei_to(exec_env, to, value) do
    account_repo =
      AccountRepo.repo(exec_env.account_repo).transfer(
        exec_env.account_repo,
        exec_env.address,
        to,
        value
      )

    %{exec_env | account_repo: account_repo}
  end

  @spec non_existent_account?(t(), EVM.Address.t()) :: {t(), boolean()}
  def non_existent_account?(exec_env, address) do
    {updated_repo, account_exists} =
      AccountRepo.repo(exec_env.account_repo).account_exists?(
        exec_env.account_repo,
        address
      )

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, !account_exists}
  end

  @spec non_existent_or_empty_account?(t(), EVM.Address.t()) :: {t(), boolean()}
  def non_existent_or_empty_account?(exec_env, address) do
    {updated_repo, is_empty_account} =
      AccountRepo.repo(exec_env.account_repo).empty_account?(
        exec_env.account_repo,
        address
      )

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    if is_empty_account do
      {updated_exec_env, true}
    else
      non_existent_account?(updated_exec_env, address)
    end
  end

  @spec account_code(t(), EVM.Address.t()) :: {t(), nil | binary()}
  def account_code(exec_env, address) do
    {updated_repo, code} =
      AccountRepo.repo(exec_env.account_repo).account_code(exec_env.account_repo, address)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, code}
  end

  @spec code_hash(t(), EVM.Address.t()) :: {t(), binary() | nil}
  def code_hash(exec_env, address) do
    {updated_repo, code_hash} =
      AccountRepo.repo(exec_env.account_repo).account_code_hash(exec_env.account_repo, address)

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, code_hash}
  end

  @spec account_nonce(t(), EVM.Address.t()) :: {t(), integer()}
  def account_nonce(exec_env, address) do
    {updated_repo, nonce} =
      AccountRepo.repo(exec_env.account_repo).account_nonce(
        exec_env.account_repo,
        address
      )

    updated_exec_env = %{exec_env | account_repo: updated_repo}

    {updated_exec_env, nonce}
  end

  @spec increment_account_nonce(t(), EVM.Address.t()) :: t()
  def increment_account_nonce(exec_env, address) do
    updated_repo =
      AccountRepo.repo(exec_env.account_repo).increment_account_nonce(
        exec_env.account_repo,
        address
      )

    %{exec_env | account_repo: updated_repo}
  end

  def create_contract(exec_env, address, available_gas, value, data) do
    block_header = BlockHeaderInfo.block_header(exec_env.block_header_info)

    AccountRepo.repo(exec_env.account_repo).create_contract(
      exec_env.account_repo,
      # sender
      exec_env.address,
      # originator
      exec_env.originator,
      # available_gas
      available_gas,
      # gas_price
      exec_env.gas_price,
      # endowment
      value,
      # init_code
      data,
      # stack_depth
      exec_env.stack_depth + 1,
      # block_header
      block_header,
      address,
      exec_env.config
    )
  end
end
