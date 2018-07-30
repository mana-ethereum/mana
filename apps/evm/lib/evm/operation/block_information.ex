defmodule EVM.Operation.BlockInformation do
  alias EVM.Operation
  alias EVM.Interface.BlockInterface

  @doc """
  Get the hash of one of the 256 most recent complete blocks.

  ## Examples

      iex> block_b = %Block.Header{number: 2, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      iex> block_a = %Block.Header{number: 1, parent_hash: <<1, 2, 3>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      iex> genesis_block = %Block.Header{number: 0, parent_hash: <<0x00::256>>, beneficiary: <<2, 3, 4>>, difficulty: 100, timestamp: 11, mix_hash: <<1>>, nonce: <<2>>}
      iex> block_map = %{<<0x00::256>> => genesis_block, "block_a" => block_a, "block_b" => block_b}
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(block_b, block_map)
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.blockhash([3], %{exec_env: exec_env})
      0
      iex> EVM.Operation.BlockInformation.blockhash([2], %{exec_env: exec_env})
      <<48, 207, 161, 118, 71, 157, 148, 188, 204, 239, 74, 169, 119, 65, 37, 100, 202, 220, 40, 100, 134, 57, 6, 35, 254, 149, 19, 241, 72, 218, 161, 220>>
      iex> EVM.Operation.BlockInformation.blockhash([1], %{exec_env: exec_env})
      <<175, 28, 231, 173, 119, 172, 237, 76, 186, 219, 115, 80, 63, 104, 191, 51, 133, 191, 250, 11, 42, 38, 53, 61, 68, 18, 98, 122, 105, 23, 209, 190>>
      iex> EVM.Operation.BlockInformation.blockhash([0], %{exec_env: exec_env})
      <<52, 135, 4, 5, 74, 2, 167, 221, 88, 74, 64, 210, 209, 25, 208, 14, 187, 181, 226, 234, 205, 235, 150, 211, 109, 83, 167, 23, 94, 231, 29, 232>>
      iex> EVM.Operation.BlockInformation.blockhash([-1], %{exec_env: exec_env})
      0
  """
  @spec blockhash(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def blockhash([block_number], %{exec_env: exec_env}) do
    current_block_number = BlockInterface.get_block_header(exec_env.block_interface).number
    block_difference = current_block_number - block_number

    block_header = BlockInterface.get_ancestor_header(exec_env.block_interface, block_difference)

    if is_nil(block_header) do
      0
    else
      Block.Header.hash(block_header)
    end
  end

  @doc """
  Get the block's beneficiary address.

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{beneficiary: <<0x55::160>>})
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.coinbase([], %{exec_env: exec_env})
      <<0x55::160>>
  """
  @spec coinbase(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def coinbase(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.beneficiary
  end

  @doc """
  Get the block's timestamp

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{timestamp: 1_000_000})
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.timestamp([], %{exec_env: exec_env})
      1_000_000
  """
  @spec timestamp(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def timestamp(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.timestamp
  end

  @doc """
  Get the block's number

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{number: 1_500_000})
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.number([], %{exec_env: exec_env})
      1_500_000
  """
  @spec number(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def number(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.number
  end

  @doc """
  Get the block's difficulty

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{difficulty: 2_000_000})
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.difficulty([], %{exec_env: exec_env})
      2_000_000
  """
  @spec difficulty(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def difficulty(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.difficulty
  end

  @doc """
  Get the block's gas limit.

  ## Examples

      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(%Block.Header{gas_limit: 3_000_000})
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.gaslimit([], %{exec_env: exec_env})
      3_000_000
  """
  @spec gaslimit(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def gaslimit(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.gas_limit
  end
end
