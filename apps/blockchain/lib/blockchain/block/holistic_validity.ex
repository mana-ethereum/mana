defmodule Blockchain.Block.HolisticValidity do
  @moduledoc """
  This module is responsible for holistic validity check, as defined in Eq.(31),
  section 4.3.2, of the Yellow Paper - Byzantium Version e94ebda.
  """

  alias Blockchain.{Block, Genesis, Chain}
  alias MerklePatriciaTree.DB

  @doc """
  Determines whether or not a block is valid. This is
  defined in Eq.(29) of the Yellow Paper.

  This is an intensive operation because we must run all transactions in the
  block to validate it

  ## Examples

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> parent_block = %Blockchain.Block{header: %Block.Header{number: 50, state_root: state.root_hash, difficulty: 50_000, timestamp: 9999, gas_limit: 125_001}}
      iex> block = Blockchain.Block.gen_child_block(parent_block, chain, beneficiary: beneficiary, timestamp: 10000, gas_limit: 125_001)
      ...>         |> Blockchain.Block.add_transactions([trx], db)
      ...>         |> Blockchain.Block.add_rewards(db)
      iex> Blockchain.Block.HolisticValidity.validate(block, chain, parent_block, db)
      :valid

      iex> db = MerklePatriciaTree.Test.random_ets_db()
      iex> chain = Blockchain.Test.ropsten_chain()
      iex> beneficiary = <<0x05::160>>
      iex> private_key = <<1::256>>
      iex> sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      iex> machine_code = EVM.MachineCode.compile([:push1, 3, :push1, 5, :add, :push1, 0x00, :mstore, :push1, 0, :push1, 32, :return])
      iex> trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
      ...>       |> Blockchain.Transaction.Signature.sign_transaction(private_key)
      iex> state = MerklePatriciaTree.Trie.new(db)
      ...>         |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
      iex> parent_block = %Blockchain.Block{header: %Block.Header{number: 50, state_root: state.root_hash, difficulty: 50_000, timestamp: 9999, gas_limit: 125_001}}
      iex> block = Blockchain.Block.gen_child_block(parent_block, chain, beneficiary: beneficiary, timestamp: 10000, gas_limit: 125_001)
      ...>         |> Blockchain.Block.add_transactions([trx], db)
      iex> %{block | header: %{block.header | state_root: <<1,2,3>>, ommers_hash: <<2,3,4>>, transactions_root: <<3,4,5>>, receipts_root: <<4,5,6>>}}
      ...> |> Blockchain.Block.validate(chain, parent_block, db)
      {:invalid, [:receipts_root_mismatch, :transactions_root_mismatch, :ommers_hash_mismatch, :state_root_mismatch]}
  """
  @spec validate(Block.t(), Chain.t(), Block.t() | nil, DB.db()) :: :valid | {:invalid, [atom()]}
  def validate(block, chain, parent_block, db) do
    base_block =
      if is_nil(parent_block) do
        Genesis.create_block(chain, db)
      else
        Block.gen_child_block(
          parent_block,
          chain,
          beneficiary: block.header.beneficiary,
          timestamp: block.header.timestamp,
          gas_limit: block.header.gas_limit,
          extra_data: block.header.extra_data
        )
      end

    child_block =
      base_block
      |> Block.add_ommers(block.ommers)
      |> Block.add_transactions(block.transactions, db, chain)
      |> Block.add_rewards(db, chain)

    # The following checks Holistic Validity,
    # as defined in Eq.(31), section 4.3.2 of Yellow Paper
    errors =
      []
      |> check_state_root_validity(child_block, block)
      |> check_ommers_hash_validity(child_block, block)
      |> check_transactions_root_validity(child_block, block)
      |> check_gas_used(child_block, block)

    # |> check_receipts_root_validity(child_block, block)
    # |> check_logs_bloom(child_block, block)

    if errors == [], do: :valid, else: {:invalid, errors}
  end

  @spec check_state_root_validity([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_state_root_validity(errors, child_block, block) do
    if child_block.header.state_root == block.header.state_root do
      errors
    else
      [:state_root_mismatch | errors]
    end
  end

  @spec check_ommers_hash_validity([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_ommers_hash_validity(errors, child_block, block) do
    if child_block.header.ommers_hash == block.header.ommers_hash do
      errors
    else
      [:ommers_hash_mismatch | errors]
    end
  end

  @spec check_transactions_root_validity([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_transactions_root_validity(errors, child_block, block) do
    if child_block.header.transactions_root == block.header.transactions_root do
      errors
    else
      [:transactions_root_mismatch | errors]
    end
  end

  @spec check_receipts_root_validity([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_receipts_root_validity(errors, child_block, block) do
    if child_block.header.receipts_root == block.header.receipts_root do
      errors
    else
      [:receipts_root_mismatch | errors]
    end
  end

  @spec check_gas_used([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_gas_used(errors, child_block, block) do
    if child_block.header.gas_used == block.header.gas_used do
      errors
    else
      [:gas_used_mismatch | errors]
    end
  end

  @spec check_logs_bloom([atom()], Block.t(), Block.t()) :: [atom()]
  defp check_logs_bloom(errors, child_block, block) do
    if child_block.header.logs_bloom == block.header.logs_bloom do
      errors
    else
      [:logs_bloom_mismatch | errors]
    end
  end
end
