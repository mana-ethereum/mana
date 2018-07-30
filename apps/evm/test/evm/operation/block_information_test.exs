defmodule EVM.Operation.BlockInformationTest do
  use ExUnit.Case, async: true
  doctest EVM.Operation.BlockInformation

  describe ".blockhash/2" do
    test "returns the hash of the block requested" do
      header_2 = build_block_header(2)
      header_1 = build_block_header(1)
      header_0 = build_block_header(0)
      block_interface = build_block_interface([header_2, header_1, header_0])
      exec_env = %EVM.ExecEnv{block_interface: block_interface}

      blockhash = EVM.Operation.BlockInformation.blockhash([0], %{exec_env: exec_env})

      assert blockhash == Block.Header.hash(header_0)
    end

    test "returns 0 if the block is not one of the most recent 256" do
      header_257 = build_block_header(257)
      header_256 = build_block_header(256)
      block_interface = build_block_interface([header_257, header_256])
      exec_env = %EVM.ExecEnv{block_interface: block_interface}

      blockhash = EVM.Operation.BlockInformation.blockhash([0], %{exec_env: exec_env})

      assert blockhash == 0
    end

    test "returns 0 if a more recent block than current block is requested" do
      header_1 = build_block_header(1)
      header_0 = build_block_header(0)
      block_interface = build_block_interface([header_1, header_0])
      exec_env = %EVM.ExecEnv{block_interface: block_interface}

      blockhash = EVM.Operation.BlockInformation.blockhash([2], %{exec_env: exec_env})

      assert blockhash == 0
    end
  end

  def build_block_interface(headers = [most_recent_header | _]) do
    block_map =
      headers
      |> Enum.map(fn header ->
        {Block.Header.hash(header), header}
      end)
      |> Enum.into(%{})

    EVM.Interface.Mock.MockBlockInterface.new(most_recent_header, block_map)
  end

  defp build_block_header(number) do
    %Block.Header{
      number: number,
      parent_hash: <<1, 2, 3>>,
      beneficiary: <<2, 3, 4>>,
      difficulty: 100,
      timestamp: 11,
      mix_hash: <<1>>,
      nonce: <<2>>
    }
  end
end
