defmodule EvmTest do
  import ExthCrypto.Math, only: [hex_to_bin: 1, hex_to_int: 1]

  alias ExthCrypto.Hash.Keccak
  alias EVM.Mock.MockAccountRepo
  alias EVM.Mock.MockBlockHeaderInfo

  use ExUnit.Case, async: true

  @ethereum_common_tests_path "../../ethereum_common_tests"
  @passing_tests_by_group %{
    sha3_test: :all,
    arithmetic_test: :all,
    bitwise_logic_operation: :all,
    block_info_test: :all,
    environmental_info: :all,
    push_dup_swap_test: :all,
    random_test: :all,
    log_test: :all,
    performance: [
      :ackermann31,
      :ackermann33,
      :fibonacci16,
      :manyFunctions100,
      :ackermann32,
      :fibonacci10

      # These tests take too long to execute but they pass.
      # :"loop-divadd-10M",
      # :"loop-exp-16b-100k",
      # :"loop-exp-2b-100k",
      # :"loop-exp-4b-100k",
      # :"loop-exp-nop-1M",
      # :"loop-mulmod-2M",
      # :"loop-add-10M",
      # :"loop-divadd-unr100-10M",
      # :"loop-exp-1b-1M",
      # :"loop-exp-32b-100k",
      # :"loop-exp-8b-100k",
      # :"loop-mul",
    ],
    i_oand_flow_operations: :all,
    system_operations: :all,
    tests: :all
  }

  test "Ethereum Common Tests" do
    for {test_group_name, _test_group} <- @passing_tests_by_group do
      for {test_name, test} <- passing_tests(test_group_name) do
        {gas, sub_state, exec_env, _} = run_test(test)

        context = %{
          test_name: test_name,
          account_repo: exec_env.account_repo,
          sub_state: sub_state,
          addresses: %{
            pre: get_addresses(test, "pre"),
            post: get_addresses(test, "post")
          }
        }

        assert_state(test, context)

        if test["gas"] do
          assert hex_to_int(test["gas"]) == gas
        end

        if test["logs"] do
          logs_hash = sub_state.logs |> logs_hash()
          assert hex_to_bin(test["logs"]) == logs_hash
        end
      end
    end
  end

  defp run_test(test) do
    exec_env = get_exec_env(test)
    gas = hex_to_int(test["exec"]["gas"])
    EVM.VM.run(gas, exec_env)
  end

  defp get_exec_env(test) do
    account_repo = account_repo(test)

    %EVM.ExecEnv{
      account_repo: account_repo,
      address: hex_to_bin(test["exec"]["address"]),
      block_header_info: block_header_info(test),
      data: hex_to_bin(test["exec"]["data"]),
      gas_price: hex_to_bin(test["exec"]["gasPrice"]),
      machine_code: hex_to_bin(test["exec"]["code"]),
      originator: hex_to_bin(test["exec"]["origin"]),
      sender: hex_to_bin(test["exec"]["caller"]),
      value_in_wei: hex_to_bin(test["exec"]["value"])
    }
  end

  def account_repo(test) do
    account_map = %{
      hex_to_bin(test["exec"]["caller"]) => %{
        balance: 0,
        code: <<>>,
        nonce: 0,
        storage: %{}
      }
    }

    account_map =
      Enum.reduce(test["pre"], account_map, fn {address, account}, address_map ->
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
      sub_state: %EVM.SubState{},
      output: <<>>
    }

    MockAccountRepo.new(
      account_map,
      contract_result
    )
  end

  def block_header_info(test) do
    genisis_block_header = %Block.Header{
      number: 0,
      mix_hash: 0
    }

    first_block_header = %Block.Header{
      number: 1,
      mix_hash: 0xC89EFDAA54C0F20C7ADF612882DF0950F5A951637E0307CDCB4C672F298B8BC6
    }

    second_block_header = %Block.Header{
      number: 2,
      mix_hash: 0xAD7C5BEF027816A800DA1736444FB58A807EF4C9603B7848673F7E3A68EB14A5
    }

    parent_block_header = %Block.Header{
      number: hex_to_int(test["env"]["currentNumber"]) - 1,
      mix_hash: 0x6CA54DA2C4784EA43FD88B3402DE07AE4BCED597CBB19F323B7595857A6720AE
    }

    last_block_header = %Block.Header{
      number: hex_to_int(test["env"]["currentNumber"]),
      timestamp: hex_to_int(test["env"]["currentTimestamp"]),
      beneficiary: hex_to_bin(test["env"]["currentCoinbase"]),
      mix_hash: 0,
      parent_hash: hex_to_int(test["env"]["currentNumber"]) - 1,
      gas_limit: hex_to_int(test["env"]["currentGasLimit"]),
      difficulty: hex_to_int(test["env"]["currentDifficulty"])
    }

    block_map = %{
      genisis_block_header.mix_hash => genisis_block_header,
      first_block_header.mix_hash => first_block_header,
      second_block_header.mix_hash => second_block_header,
      parent_block_header.mix_hash => parent_block_header,
      last_block_header.mix_hash => last_block_header
    }

    MockBlockHeaderInfo.new(
      last_block_header,
      block_map
    )
  end

  def passing_tests(test_group_name) do
    tests =
      if Map.get(@passing_tests_by_group, test_group_name) == :all do
        all_tests_of_type(test_group_name)
      else
        Map.get(@passing_tests_by_group, test_group_name)
      end

    tests
    |> Enum.map(fn test_name ->
      {test_name, read_test_file(test_group_name, test_name)}
    end)
  end

  def read_test_file(group, name) do
    {:ok, body} = File.read(test_file_name(group, name))
    Poison.decode!(body)[name |> Atom.to_string()]
  end

  def all_tests_of_type(type) do
    {:ok, files} = File.ls(test_directory_name(type))

    Enum.map(files, fn file_name ->
      file_name
      |> String.replace_suffix(".json", "")
      |> String.to_atom()
    end)
  end

  def test_directory_name(type) do
    "#{@ethereum_common_tests_path}/VMTests/vm#{Macro.camelize(Atom.to_string(type))}"
  end

  def test_file_name(group, name) do
    "#{@ethereum_common_tests_path}/VMTests/vm#{Macro.camelize(Atom.to_string(group))}/#{name}.json"
  end

  def assert_state(test, context) do
    if Map.get(test, "post") do
      expected = expected_state(test, context)
      actual = actual_state(test, context)
      assert expected == actual
    end
  end

  defp expected_state(test, _context) do
    post = Map.get(test, "post", %{})

    for {address, account_state} <- post, into: %{} do
      storage = Map.get(account_state, "storage")

      storage =
        for {key, value} <- storage, into: %{} do
          {hex_to_bin(key), hex_to_int(value)}
        end

      account = %{
        storage: storage,
        balance: hex_to_int(account_state["balance"]),
        code: hex_to_bin(account_state["code"]),
        nonce: hex_to_int(account_state["nonce"])
      }

      {hex_to_bin(address), account}
    end
    |> Enum.into(%{})
  end

  defp actual_state(test, context) do
    caller = hex_to_bin(test["exec"]["caller"])
    # exclude caller's account from the actual state
    # if it isn't in the "pre" or "post" addresses
    context.account_repo.account_map
    |> Enum.reject(fn {address, _} ->
      Enum.member?(context.sub_state.selfdestruct_list, address)
    end)
    |> Enum.reject(fn {address, _} ->
      address == caller && !Enum.member?(context.addresses.pre, address) &&
        !Enum.member?(context.addresses.post, address)
    end)
    |> Enum.into(%{}, fn {address, account_state} ->
      storage =
        account_state[:storage]
        |> Enum.reject(fn {_key, value} -> value == 0 end)
        |> Enum.into(%{}, fn {key, value} ->
          {:binary.encode_unsigned(key), value}
        end)

      account = %{account_state | storage: storage}

      {address, account}
    end)
  end

  defp logs_hash(logs) do
    logs
    |> ExRLP.encode()
    |> Keccak.kec()
  end

  defp get_addresses(test, state_key) do
    test
    |> Map.get(state_key, %{})
    |> Map.keys()
    |> Enum.map(&hex_to_bin/1)
  end
end
