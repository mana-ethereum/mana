defmodule EVM.Operation.BlockInformation do
  alias EVM.Operation
  alias EVM.Interface.BlockInterface

  @doc """
  Get the hash of one of the 256 most recent complete blocks.

  # TODO: Test 256 limit

  ## Examples

      iex> block_b = %Block.Header{number: 2, mix_hash: "block_b"}
      iex> block_a = %Block.Header{number: 1, mix_hash: "block_a"}
      iex> genesis_block = %Block.Header{number: 0, mix_hash: <<0x00::256>>}
      iex> block_map = %{<<0x00::256>> => genesis_block, "block_a" => block_a, "block_b" => block_b}
      iex> block_interface = EVM.Interface.Mock.MockBlockInterface.new(block_b, block_map)
      iex> exec_env = %EVM.ExecEnv{block_interface: block_interface}
      iex> EVM.Operation.BlockInformation.blockhash([3], %{exec_env: exec_env})
      0
      iex> EVM.Operation.BlockInformation.blockhash([2], %{exec_env: exec_env})
      "block_b"
      iex> EVM.Operation.BlockInformation.blockhash([1], %{exec_env: exec_env})
      "block_a"
      iex> EVM.Operation.BlockInformation.blockhash([0], %{exec_env: exec_env})
      <<0::256>>
      iex> EVM.Operation.BlockInformation.blockhash([-1], %{exec_env: exec_env})
      0
  """
  @spec blockhash(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def blockhash([block_number], %{exec_env: exec_env}) do
    block_difference = exec_env.block_interface.block_header.number - block_number
    if block_difference > 256 || block_difference < 0 do
      0
    else
      block_header = BlockInterface.get_block_by_number(exec_env.block_interface, block_number)
      if block_header, do: block_header.mix_hash, else: 0
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
  @spec coinbase(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec timestamp(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec number(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec difficulty(Operation.stack_args, Operation.vm_map) :: Operation.op_result
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
  @spec gaslimit(Operation.stack_args, Operation.vm_map) :: Operation.op_result
  def gaslimit(_args, %{exec_env: exec_env}) do
    block_header = BlockInterface.get_block_header(exec_env.block_interface)

    block_header.gas_limit
  end
end
