defmodule EVM.TestRunner do
  import ExthCrypto.Math, only: [hex_to_bin: 1, hex_to_int: 1]

  alias EVM.Mock.{MockAccountRepo, MockBlockHeaderInfo}
  alias EVM.{ExecEnv, SubState, VM}

  def run(json) do
    exec_env = get_exec_env(json)
    gas = hex_to_int(json["exec"]["gas"])
    VM.run(gas, exec_env)
  end

  defp get_exec_env(json) do
    %ExecEnv{
      address: hex_to_bin(json["exec"]["address"]),
      originator: hex_to_bin(json["exec"]["origin"]),
      gas_price: hex_to_int(json["exec"]["gasPrice"]),
      data: hex_to_bin(json["exec"]["data"]),
      sender: hex_to_bin(json["exec"]["caller"]),
      value_in_wei: hex_to_int(json["exec"]["value"]),
      machine_code: hex_to_bin(json["exec"]["code"]),
      account_repo: account_repo(json),
      block_header_info: block_header_info(json)
    }
  end

  defp block_header_info(json) do
    if json["env"]["currentNumber"] == "0x00" do
      single_block_header_info(json)
    else
      many_blocks_header_info(json)
    end
  end

  defp single_block_header_info(json) do
    build_block_header_info([
      %Block.Header{
        number: hex_to_int(json["env"]["currentNumber"]),
        timestamp: hex_to_int(json["env"]["currentTimestamp"]),
        beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
        mix_hash: <<0::256>>,
        parent_hash: <<0::256>>,
        gas_limit: hex_to_int(json["env"]["currentGasLimit"]),
        difficulty: hex_to_int(json["env"]["currentDifficulty"])
      }
    ])
  end

  defp many_blocks_header_info(json) do
    genesis_block_header = %Block.Header{
      number: 0,
      timestamp: hex_to_int(json["env"]["currentTimestamp"]) - 1,
      beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
      mix_hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
      parent_hash: 0,
      difficulty: hex_to_int(json["env"]["currentDifficulty"]) - 4
    }

    first_block_header = %Block.Header{
      number: 1,
      timestamp: hex_to_int(json["env"]["currentTimestamp"]) - 1,
      beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
      mix_hash: 0xC89EFDAA54C0F20C7ADF612882DF0950F5A951637E0307CDCB4C672F298B8BC6,
      parent_hash: 0,
      difficulty: hex_to_int(json["env"]["currentDifficulty"]) - 3
    }

    second_block_header = %Block.Header{
      number: 2,
      timestamp: hex_to_int(json["env"]["currentTimestamp"]) - 1,
      beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
      mix_hash: 0xAD7C5BEF027816A800DA1736444FB58A807EF4C9603B7848673F7E3A68EB14A5,
      parent_hash: 0xC89EFDAA54C0F20C7ADF612882DF0950F5A951637E0307CDCB4C672F298B8BC6,
      difficulty: hex_to_int(json["env"]["currentDifficulty"]) - 2
    }

    parent_block_header = %Block.Header{
      number: hex_to_int(json["env"]["currentNumber"]) - 1,
      timestamp: hex_to_int(json["env"]["currentTimestamp"]) - 1,
      beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
      mix_hash: 0x6CA54DA2C4784EA43FD88B3402DE07AE4BCED597CBB19F323B7595857A6720AE,
      parent_hash: 0xAD7C5BEF027816A800DA1736444FB58A807EF4C9603B7848673F7E3A68EB14A5,
      difficulty: hex_to_int(json["env"]["currentDifficulty"]) - 1
    }

    last_block_header = %Block.Header{
      number: hex_to_int(json["env"]["currentNumber"]),
      timestamp: hex_to_int(json["env"]["currentTimestamp"]),
      beneficiary: hex_to_bin(json["env"]["currentCoinbase"]),
      mix_hash: 0x0000000000000000000000000000000000000000000000000000000000000000,
      parent_hash: 0x6CA54DA2C4784EA43FD88B3402DE07AE4BCED597CBB19F323B7595857A6720AE,
      gas_limit: hex_to_int(json["env"]["currentGasLimit"]),
      difficulty: hex_to_int(json["env"]["currentDifficulty"])
    }

    build_block_header_info([
      last_block_header,
      parent_block_header,
      second_block_header,
      first_block_header,
      genesis_block_header
    ])
  end

  defp build_block_header_info(headers = [most_recent_header | _]) do
    block_map =
      Enum.into(headers, %{}, fn header ->
        {Block.Header.hash(header), header}
      end)

    MockBlockHeaderInfo.new(most_recent_header, block_map)
  end

  defp account_repo(json) do
    account_map = %{
      hex_to_bin(json["exec"]["caller"]) => %{
        balance: 0,
        code: <<>>,
        nonce: 0,
        storage: %{}
      }
    }

    account_map =
      Enum.reduce(json["pre"], account_map, fn {address, account}, address_map ->
        storage =
          account["storage"]
          |> Enum.into(%{}, fn {key, value} ->
            {hex_to_int(key), hex_to_int(value)}
          end)

        Map.merge(address_map, %{
          hex_to_bin(address) => %{
            balance: hex_to_int(account["balance"]),
            code: hex_to_bin(account["code"]),
            nonce: hex_to_int(account["nonce"]),
            storage: storage
          }
        })
      end)

    contract_result = %{
      gas: 0,
      sub_state: %SubState{},
      output: <<>>
    }

    MockAccountRepo.new(
      account_map,
      contract_result
    )
  end
end
