defmodule Blockchain.Chain do
  @moduledoc """
  Represents the information about a specific chain. This
  will either be a current chain (such as homestead), or
  a test chain (such as ropsten). Different chains have
  different parameters, such as accounts with an initial
  balance and when EIPs are implemented.

  For compatibility, we'll use the configuration files from Parity:
  https://github.com/paritytech/parity/tree/master/ethcore/res/ethereum
  """

  require Integer

  defstruct [
    name: nil,
    engine: %{},
    params: %{},
    genesis: %{},
    nodes: [],
    accounts: %{}
  ]

  @type t :: %__MODULE__{
    name: String.t,
    engine: %{
      String.t => %{
        minimum_difficulty: integer(),
        difficulty_bound_divisor: integer(),
        duration_limit: integer(),
        homestead_transition: integer(),
        eip150_transition: integer(),
        eip160_transition: integer(),
        eip161abc_transition: integer(),
        eip161d_transition: integer(),
        max_code_size: integer()
      }
    },
    params: %{
      gas_limit_bound_divisor: integer(),
      block_reward: integer(),
      account_start_nonce: integer(),
      maximum_extra_data_size: integer(),
      min_gas_limit: integer(),
      eip155_transition: integer(),
      eip98_transition: integer(),
      eip86_transition: integer(),
    },
    genesis: %{
      difficulty: integer(),
      author: EVM.address,
      timestamp: integer(),
      parent_hash: EVM.hash,
      extra_data: binary(),
      gas_limit: EVM.Gas.t
    },
    nodes: [String.t],
    accounts: %{
      EVM.address => %{
        balance: EVM.Wei.t,
        nonce: integer(),
        # TODO: Handle built-in
      }
    }
  }

  @doc """
  Loads a given blockchain, such as Homestead or Ropsten. This
  chain is used to set the genesis block and tweak parameters
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

    %__MODULE__{
      name: chain_data["name"],
      engine: get_engine(chain_data["engine"]),
      params: get_params(chain_data["params"]),
      genesis: get_genesis(chain_data["genesis"]),
      nodes: chain_data["nodes"],
      accounts: get_accounts(chain_data["accounts"])
    }
  end

  defp get_engine(engine_map) do
    for {engine, %{"params" => params}} <- engine_map do
      {engine, %{
        minimum_difficulty: params["minimumDifficulty"] |> load_hex,
        difficulty_bound_divisor: params["difficultyBoundDivisor"] |> load_hex,
        duration_limit: params["durationLimit"] |> load_hex,
        homestead_transition: params["homesteadTransition"],
        eip150_transition: params["eip150Transition"],
        eip160_transition: params["eip160Transition"],
        eip161abc_transition: params["eip161abcTransition"],
        eip161d_transition: params["eip161dTransition"],
        max_code_size: params["maxCodeSize"],
        }}
    end |> Enum.into(%{})
  end

  defp get_params(params_map) do
    %{
      gas_limit_bound_divisor: params_map["gasLimitBoundDivisor"] |> load_hex,
      block_reward: params_map["blockReward"] |> load_hex,
      account_start_nonce: params_map["accountStartNonce"] |> load_hex,
      maximum_extra_data_size: params_map["maximumExtraDataSize"] |> load_hex,
      min_gas_limit: params_map["minGasLimit"] |> load_hex,
      eip155_transition: params_map["eip155Transition"],
      eip98_transition: params_map["eip98Transition"] |> load_hex,
      eip86_transition: params_map["eip86Transition"] |> load_hex,
    }
  end

  defp get_genesis(genesis_map) do
    %{
      difficulty: genesis_map["difficulty"] |> load_hex,
      author: genesis_map["author"] |> load_address,
      timestamp: genesis_map["timestamp"] |> load_hex,
      parent_hash: genesis_map["parentHash"] |> load_raw_hex,
      extra_data: genesis_map["extraData"] |> load_raw_hex,
      gas_limit: genesis_map["gasLimit"] |> load_hex,
    }
  end

  defp get_accounts(account_map) do
    for {address, account_info} <- account_map do
      {load_address(address), %{
        balance: account_info["balance"] |> load_hex,
        nonce: ( if account_info["nonce"], do: account_info["nonce"] |> load_hex, else: 0 ),
      }}
    end |> Enum.into(%{})
  end

  @spec read_chain!(atom()) :: map()
  defp read_chain!(chain) do
    {:ok, body} = File.read(chain |> chain_filename)

    Poison.decode!(body)
  end

  @spec chain_filename(atom()) :: String.t
  defp chain_filename(chain) do
    "chains/#{Atom.to_string(chain)}.json"
  end

  @spec load_address(String.t) :: binary()
  defp load_address(hex_data), do: load_raw_hex(hex_data)

  @spec load_raw_hex(String.t) :: binary()
  defp load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)
  defp load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)), do: load_raw_hex("0" <> hex_data)
  defp load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end


  @spec load_hex(String.t) :: integer()
  defp load_hex(hex_data), do: hex_data |> load_raw_hex |> :binary.decode_unsigned

end