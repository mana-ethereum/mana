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
    genesis: %{},
    nodes: [],
    accounts: %{}
  ]

  @type t :: %__MODULE__{
    name: String.t,
    engine: %{
      String.t => %{
        params: %{
          minimumDifficulty: integer(),
          difficultyBoundDivisor: integer(),
          durationLimit: integer(),
          homesteadTransition: integer(),
          eip150Transition: integer(),
          eip160Transition: integer(),
          eip161abcTransition: integer(),
          eip161dTransition: integer(),
          maxCodeSize: integer()
        }
      }
    },
    genesis: %{
      difficulty: integer(),
      author: EVM.address,
      timestamp: integer(),
      parent_hash: EVM.hash,
      extra_data: :binary,
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

  @spec load_blockchain(atom()) :: t
  def load_blockchain(chain) do
    chain_data = read_chain!(chain)

    %__MODULE__{
      name: chain_data["name"],
      engine: get_engine(chain_data["engine"]),
      genesis: get_genesis(chain_data["genesis"]),
      nodes: chain_data["nodes"],
      accounts: get_accounts(chain_data["accounts"])
    }
  end

  defp get_engine(engine_map) do
    for {engine, %{"params" => params}} <- engine_map do
      {engine, %{
        minimumDifficulty: params["minimumDifficulty"] |> load_hex,
        difficultyBoundDivisor: params["difficultyBoundDivisor"] |> load_hex,
        durationLimit: params["durationLimit"] |> load_hex,
        homesteadTransition: params["homesteadTransition"],
        eip150Transition: params["eip150Transition"],
        eip160Transition: params["eip160Transition"],
        eip161abcTransition: params["eip161abcTransition"],
        eip161dTransition: params["eip161dTransition"],
        maxCodeSize: params["maxCodeSize"],
        }}
    end |> Enum.into(%{})
  end

  defp get_genesis(genesis_map) do
    %{
      difficulty: genesis_map["difficulty"] |> load_hex,
      author: genesis_map["author"] |> load_hex,
      timestamp: genesis_map["timestamp"] |> load_hex,
      parentHash: genesis_map["parentHash"] |> load_hex,
      extraData: genesis_map["extraData"] |> load_hex,
      gasLimit: genesis_map["gasLimit"] |> load_hex,
    }
  end

  defp get_accounts(account_map) do
    for {address, account_info} <- account_map do
      {load_hex(address), %{
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

  @spec load_hex(String.t) :: integer()
  defp load_hex("0x" <> hex_data), do: load_hex(hex_data)
  defp load_hex(hex_data) when Integer.is_odd(byte_size(hex_data)), do: load_hex("0" <> hex_data)
  defp load_hex(hex_data) do
    IO.inspect(hex_data)
    Base.decode16!(hex_data, case: :lower)
  end

end