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
            accounts: %{}

  @type engine :: %{
          minimum_difficulty: integer(),
          difficulty_bound_divisor: integer(),
          duration_limit: integer(),
          block_reward: integer(),
          homestead_transition: integer(),
          eip649_reward: integer(),
          eip100b_transition: integer(),
          eip649_transition: integer()
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
          eip658_transition: integer()
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
          accounts: %{EVM.address() => account() | builtin_account()}
        }

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
  @spec load_chain(atom()) :: t
  def load_chain(chain) do
    chain_data = read_chain!(chain)

    engine =
      chain_data["engine"]
      |> Enum.map(&get_engine/1)
      |> Enum.into(%{})

    accounts =
      chain_data["accounts"]
      |> get_accounts()

    %__MODULE__{
      name: chain_data["name"],
      engine: engine,
      params: get_params(chain_data["params"]),
      genesis: get_genesis(chain_data["genesis"]),
      nodes: chain_data["nodes"],
      accounts: accounts
    }
  end

  @spec get_engine({String.t(), map}) :: {String.t(), engine()}
  defp get_engine({engine, %{"params" => params}}) do
    config = %{
      minimum_difficulty: params["minimumDifficulty"] |> load_hex(),
      difficulty_bound_divisor: params["difficultyBoundDivisor"] |> load_hex(),
      duration_limit: params["durationLimit"] |> load_hex(),
      block_reward: params["blockReward"] |> load_hex(),
      homestead_transition: params["homesteadTransition"] |> load_hex(),
      eip649_reward: params["eip649Reward"] |> load_hex(),
      eip100b_transition: params["eip100bTransition"] |> load_hex(),
      eip649_transition: params["eip649Transition"] |> load_hex()
    }

    {engine, config}
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
      eip658_transition: map["eip658Transition"] |> load_hex()
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
      nonce: map["ethereum"]["nonce"] |> load_hex(),
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
    Poison.decode!(body)
  end

  @spec chain_filename(atom()) :: String.t()
  defp chain_filename(chain) do
    Path.expand("../../../../chains/#{Atom.to_string(chain)}.json", __DIR__)
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
