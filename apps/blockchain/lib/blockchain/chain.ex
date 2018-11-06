defmodule Blockchain.Chain do
  @moduledoc """
  Represents the information about a specific chain.
  This will either be a current chain (such as homestead), or
  a test chain (such as ropsten). Different chains have
  different parameters, such as accounts with an initial
  balance and when EIPs are implemented.

  For compatibility, we'll use the configuration files from Parity:
  https://github.com/paritytech/parity/tree/master/ethcore/res/ethereum
  """

  require Integer

  alias Blockchain.Genesis

  defstruct name: nil,
            engine: %{},
            params: %{},
            genesis: %{},
            nodes: [],
            accounts: %{},
            evm_config: nil

  @type engine :: %{
          minimum_difficulty: integer(),
          difficulty_bound_divisor: integer(),
          duration_limit: integer(),
          block_rewards: [{integer(), integer()}],
          homestead_transition: integer(),
          eip649_reward: integer(),
          eip100b_transition: integer(),
          eip649_transition: integer(),
          difficulty_bomb_delays: [{integer(), integer()}],
          dao_hardfork_transition: integer() | nil,
          dao_hardfork_accounts: [binary()] | nil,
          dao_hardfork_beneficiary: binary() | nil
        }

  @type params :: %{
          gas_limit_bound_divisor: integer(),
          registrar: EVM.address(),
          account_start_nonce: integer(),
          maximum_extra_data_size: integer(),
          min_gas_limit: integer(),
          network_id: integer(),
          fork_block: integer(),
          fork_canon_hash: EVM.hash(),
          max_code_size: integer(),
          max_code_size_transition: integer(),
          eip150_transition: integer(),
          eip160_transition: integer(),
          eip161abc_transition: integer(),
          eip161d_transition: integer(),
          eip155_transition: integer(),
          eip98_transition: integer(),
          eip86_transition: integer(),
          eip140_transition: integer(),
          eip211_transition: integer(),
          eip214_transition: integer(),
          eip658_transition: integer(),
          eip145_transition: integer(),
          eip1014_transition: integer(),
          eip1052_transition: integer(),
          eip1283_transition: integer()
        }

  @type account :: %{
          balance: EVM.Wei.t(),
          nonce: integer(),
          storage: %{
            binary() => binary()
          }
        }

  @type builtin_account :: %{
          name: String.t(),
          balance: integer(),
          nonce: integer(),
          pricing: %{
            linear: %{
              base: integer(),
              word: integer()
            }
          }
        }

  @type t :: %__MODULE__{
          name: String.t(),
          engine: %{String.t() => engine()},
          params: params(),
          genesis: Genesis.t(),
          nodes: [String.t()],
          accounts: %{EVM.address() => account() | builtin_account()},
          evm_config: EVM.Configuration.t()
        }

  @dao_extra_range 9

  @doc """
  Loads a given blockchain, such as Homestead or Ropsten.
  This chain is used to set the genesis block and tweak parameters
  of the Blockchain and EVM.

  See the `/chains` directory of this repo for supported
  block chains.

  ## Examples

      iex> Blockchain.Chain.load_chain(:ropsten).name
      "Ropsten"

      iex> Blockchain.Chain.load_chain(:ropsten).genesis.difficulty
      0x100000
  """
  @spec load_chain(atom(), EVM.Configuration.t() | nil) :: t
  def load_chain(chain, evm_config \\ nil) do
    chain_data = read_chain!(chain)

    engine = Enum.into(chain_data["engine"], %{}, &get_engine/1)

    accounts =
      chain_data["accounts"]
      |> get_accounts()

    %__MODULE__{
      name: chain_data["name"],
      engine: engine,
      params: get_params(chain_data["params"]),
      genesis: get_genesis(chain_data["genesis"]),
      nodes: chain_data["nodes"],
      accounts: accounts,
      evm_config: evm_config
    }
  end

  @doc """
  Gets a test chain configuration (along with the respective EVM configuration)
  based on a hardfork.

  ## Examples

      iex> Blockchain.Chain.test_config("Frontier").name
      "Frontier (Test)"
  """
  def test_config(hardfork) when is_binary(hardfork) do
    config = EVM.Configuration.hardfork_config(hardfork)

    case hardfork do
      "Frontier" ->
        load_chain(:frontier_test, config)

      "Homestead" ->
        load_chain(:homestead_test, config)

      "TangerineWhistle" ->
        load_chain(:eip150_test, config)

      "SpuriousDragon" ->
        load_chain(:eip161_test, config)

      "Byzantium" ->
        load_chain(:byzantium_test, config)

      "Constantinople" ->
        load_chain(:constantinople_test, config)

      "HomesteadToDaoAt5" ->
        load_chain(:dao_hardfork_test, config)

      _ ->
        nil
    end
  end

  @doc """
  Get the EVM configuration based on the chain and block number
  """
  def evm_config(chain = %__MODULE__{}, block_number \\ nil) do
    if block_number do
      cond do
        block_number >= chain.params.eip1283_transition ->
          EVM.Configuration.Constantinople.new()

        block_number >= chain.params.eip658_transition ->
          EVM.Configuration.Byzantium.new()

        block_number >= chain.params.eip160_transition ->
          EVM.Configuration.SpuriousDragon.new()

        block_number >= chain.params.eip150_transition ->
          EVM.Configuration.TangerineWhistle.new()

        block_number >= chain.engine["Ethash"].homestead_transition ->
          EVM.Configuration.Homestead.new()

        true ->
          EVM.Configuration.Frontier.new()
      end
    else
      chain.evm_config
    end
  end

  @doc """
  Convenience function to determine whether a block number is after the
  bomb delays introduced in Byzantium and Constantinople
  """
  @spec after_bomb_delays?(t(), integer()) :: boolean()
  def after_bomb_delays?(chain = %__MODULE__{}, block_number) do
    bomb_delays = chain.engine["Ethash"][:difficulty_bomb_delays]

    Enum.any?(bomb_delays, fn {hard_fork_number, _delay} ->
      block_number >= hard_fork_number
    end)
  end

  @doc """
  Function to determine what the bomb delay is for a block number.

  Note: This function should not be called on a block number that happens before
  bomb delays. Before bomb delays were introduced, the difficulty calculation
  was different and thus we do not expect a bomb delay at all.
  """
  @spec bomb_delay_factor_for_block(t, integer()) :: integer()
  def bomb_delay_factor_for_block(chain = %__MODULE__{}, block_number) do
    bomb_delays = chain.engine["Ethash"][:difficulty_bomb_delays]

    {_, delay} =
      bomb_delays
      |> Enum.sort(fn {k1, _}, {k2, _} -> k1 < k2 end)
      |> Enum.take_while(fn {k, _} -> k <= block_number end)
      |> List.last()

    delay
  end

  @doc """
  Determines the base reward for a block number. The reward changed was lowered
  in Byzantium and again in Constantinople
  """
  @spec block_reward_for_block(t, integer()) :: integer()
  def block_reward_for_block(chain = %__MODULE__{}, block_number) do
    {_k, reward} =
      chain.engine["Ethash"][:block_rewards]
      |> Enum.sort(fn {k, _}, {k2, _} -> k < k2 end)
      |> Enum.take_while(fn {k, _} -> k <= block_number end)
      |> List.last()

    reward
  end

  def support_dao_fork?(chain) do
    !is_nil(chain.engine["Ethash"][:dao_hardfork_transition])
  end

  def dao_fork?(chain, block_number) do
    chain.engine["Ethash"][:dao_hardfork_transition] == block_number
  end

  def within_dao_fork_extra_range?(chain, block_number) do
    dao_hardfork = chain.engine["Ethash"][:dao_hardfork_transition]
    block_number >= dao_hardfork && block_number <= dao_hardfork + @dao_extra_range
  end

  @doc """
  Helper function to determine if block number is after the homestead transition
  based on the chain configuration.
  """
  @spec after_homestead?(t, integer()) :: boolean()
  def after_homestead?(chain, block_number) do
    homestead_block = chain.engine["Ethash"][:homestead_transition]

    block_number >= homestead_block
  end

  @doc """
  Helper function to determine if block number is after the byzantium transition
  based on the chain configuration.
  """
  @spec after_byzantium?(t, integer()) :: boolean()
  def after_byzantium?(chain, block_number) do
    eip658_transition = chain.params[:eip658_transition]

    block_number >= eip658_transition
  end

  @spec get_engine({String.t(), map}) :: {String.t(), engine()}
  defp get_engine({engine, %{"params" => params}}) do
    config = %{
      minimum_difficulty: params["minimumDifficulty"] |> load_hex(),
      difficulty_bound_divisor: params["difficultyBoundDivisor"] |> load_hex(),
      duration_limit: params["durationLimit"] |> load_hex(),
      block_rewards: params["blockReward"] |> parse_reward(),
      homestead_transition: params["homesteadTransition"] |> load_hex(),
      eip649_reward: params["eip649Reward"] |> load_hex(),
      eip100b_transition: params["eip100bTransition"] |> load_hex(),
      eip649_transition: params["eip649Transition"] |> load_hex(),
      difficulty_bomb_delays: params["difficultyBombDelays"] |> parse_bomb_delays(),
      dao_hardfork_transition: params["daoHardforkTransition"] |> load_hex(),
      dao_hardfork_accounts: params["daoHardforkAccounts"] |> parse_dao_accounts(),
      dao_hardfork_beneficiary: params["daoHardforkBeneficiary"] |> load_raw_hex()
    }

    {engine, config}
  end

  defp parse_dao_accounts(nil), do: []

  defp parse_dao_accounts(accounts) do
    Enum.map(accounts, &load_raw_hex/1)
  end

  defp parse_reward(block_reward) when is_binary(block_reward) do
    [{load_hex("0x00"), load_hex(block_reward)}]
  end

  defp parse_reward(block_rewards) do
    Enum.map(block_rewards, fn {k, v} ->
      {block_number, _} = Integer.parse(k)
      {block_number, load_hex(v)}
    end)
  end

  defp parse_bomb_delays(nil), do: []

  defp parse_bomb_delays(bomb_delays) do
    Enum.map(bomb_delays, fn {k, v} ->
      {block_number, _} = Integer.parse(k)
      {block_number, v}
    end)
  end

  @spec get_params(map) :: params()
  defp get_params(map) do
    %{
      gas_limit_bound_divisor: map["gasLimitBoundDivisor"] |> load_hex(),
      registrar: map["registrar"] |> load_raw_hex(),
      account_start_nonce: map["accountStartNonce"] |> load_hex(),
      maximum_extra_data_size: map["maximumExtraDataSize"] |> load_hex(),
      min_gas_limit: map["minGasLimit"] |> load_hex(),
      network_id: map["networkID"] |> load_hex(),
      fork_block: map["forkBlock"] |> load_hex(),
      fork_canon_hash: map["forkCanonHash"] |> load_raw_hex(),
      max_code_size: map["maxCodeSize"] |> load_hex(),
      max_code_size_transition: map["maxCodeSizeTransition"] |> load_hex(),
      eip150_transition: map["eip150Transition"] |> load_hex(),
      eip160_transition: map["eip160Transition"] |> load_hex(),
      eip161abc_transition: map["eip161abcTransition"] |> load_hex(),
      eip161d_transition: map["eip161dTransition"] |> load_hex(),
      eip155_transition: map["eip155Transition"] |> load_hex(),
      eip98_transition: map["eip98Transition"] |> load_hex(),
      eip86_transition: map["eip86Transition"] |> load_hex(),
      eip140_transition: map["eip140Transition"] |> load_hex(),
      eip211_transition: map["eip211Transition"] |> load_hex(),
      eip214_transition: map["eip214Transition"] |> load_hex(),
      eip658_transition: map["eip658Transition"] |> load_hex(),
      eip145_transition: map["eip145Transition"] |> load_hex(),
      eip1014_transition: map["eip1014Transition"] |> load_hex(),
      eip1052_transition: map["eip1052Transition"] |> load_hex(),
      eip1283_transition: map["eip1283Transition"] |> load_hex()
    }
  end

  @spec get_genesis(map) :: Genesis.t()
  defp get_genesis(map) do
    %{
      seal: get_genesis_seal(map["seal"]),
      difficulty: map["difficulty"] |> load_hex(),
      author: map["author"] |> load_raw_hex(),
      timestamp: map["timestamp"] |> load_hex(),
      parent_hash: map["parentHash"] |> load_raw_hex(),
      extra_data: map["extraData"] |> load_raw_hex(),
      gas_limit: map["gasLimit"] |> load_hex()
    }
  end

  @spec get_genesis_seal(map | nil) :: Genesis.seal_config() | nil
  defp get_genesis_seal(nil), do: nil

  defp get_genesis_seal(map) do
    %{
      nonce: map["ethereum"]["nonce"] |> load_raw_hex(),
      mix_hash: map["ethereum"]["mixHash"] |> load_raw_hex()
    }
  end

  defp get_accounts(json_accounts) do
    accounts =
      Enum.reduce(json_accounts, [], fn json_account = {_address, info}, acc ->
        account =
          if is_nil(info["builtin"]) do
            get_account(json_account)
          else
            get_builtin_account(json_account)
          end

        [account | acc]
      end)

    Enum.into(accounts, %{})
  end

  defp get_account({raw_address, info}) do
    nonce =
      if info["nonce"],
        do: info["nonce"] |> load_hex(),
        else: 0

    address = load_raw_hex(raw_address)

    account = %{
      balance: info["balance"] |> load_decimal(),
      nonce: nonce
    }

    {address, account}
  end

  defp get_builtin_account({raw_address, info}) do
    address = load_raw_hex(raw_address)

    balance = if info["balance"], do: load_decimal(info["balance"])

    nonce =
      if info["nonce"],
        do: load_hex(info["nonce"]),
        else: 0

    builtin_account = %{
      name: info["builtin"]["name"],
      pricing: %{
        linear: %{
          base: info["builtin"]["pricing"]["linear"]["base"],
          word: info["builtin"]["pricing"]["linear"]["word"]
        }
      },
      balance: balance,
      nonce: nonce
    }

    {address, builtin_account}
  end

  @spec read_chain!(atom()) :: map()
  defp read_chain!(chain) do
    filename = chain_filename(chain)
    {:ok, body} = File.read(filename)
    Jason.decode!(body)
  end

  @spec chain_filename(atom()) :: String.t()
  defp chain_filename(chain) do
    Path.expand("../../../../chains/#{Atom.to_string(chain)}.json", __DIR__)
  end

  @doc """
  Given a string (e.g. user input), returns either a valid atom
  referencing a chain or `:not_found`.

  ## Examples

    iex> Blockchain.Chain.id_from_string("ropsten")
    {:ok, :ropsten}

    iex> Blockchain.Chain.id_from_string("jungle")
    :not_found
  """
  @spec id_from_string(String.t()) :: {:ok, atom()} | :not_found
  def id_from_string(chain_name) do
    case chain_name do
      "ropsten" ->
        {:ok, :ropsten}

      "foundation" ->
        {:ok, :foundation}

      _ ->
        :not_found
    end
  end

  @spec load_raw_hex(String.t() | nil) :: binary()
  defp load_raw_hex(nil), do: nil
  defp load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)

  defp load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)),
    do: load_raw_hex("0" <> hex_data)

  defp load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end

  @spec load_decimal(String.t()) :: integer()
  defp load_decimal(dec_data) do
    {res, ""} = Integer.parse(dec_data)

    res
  end

  @spec load_hex(String.t() | integer()) :: integer()
  defp load_hex(nil), do: nil
  defp load_hex(x) when is_integer(x), do: x
  defp load_hex(x), do: x |> load_raw_hex |> :binary.decode_unsigned()
end
