defmodule Blockchain.TransactionTest do
  use ExUnit.Case, async: true
  use EthCommonTest.Harness
  doctest Blockchain.Transaction

  require Logger

  alias Blockchain.Transaction
  alias Blockchain.Transaction.Signature

  # Load filler data
  setup_all do
    frontier_filler = load_src("TransactionTestsFiller", "ttTransactionTestFiller")
    homestead_filler = load_src("TransactionTestsFiller/Homestead", "ttTransactionTestFiller")
    eip155_filler = load_src("TransactionTestsFiller/EIP155", "ttTransactionTestEip155VitaliksTestsFiller")

    {:ok, %{
      frontier_filler: frontier_filler,
      homestead_filler: homestead_filler,
      eip155_filler: eip155_filler}}
  end

  eth_test "TransactionTests", :ttTransactionTest, :all, fn test, test_subset, test_name, %{frontier_filler: filler} ->
    trx_data = test["transaction"]
    src_data = filler[test_name]
    transaction = (trx_data || src_data["transaction"]) |> load_trx

    if src_data["expect"] == "invalid" do
      # TODO: Include checks of "invalid" tests
      Logger.debug("Skipping `invalid` transaction test: TransactionTests - #{test_subset} - #{test_name}")

      nil
    else
      assert transaction |> Transaction.serialize == test["rlp"] |> load_hex |> :binary.encode_unsigned |> ExRLP.decode

      if test["hash"], do: assert transaction |> Transaction.serialize |> ExRLP.encode |> BitHelper.kec == test["hash"] |> maybe_hex
      if test["sender"], do: assert Signature.sender(transaction) == {:ok, test["sender"] |> maybe_hex}
    end
  end

  # Test Homestead
  eth_test "TransactionTests/Homestead", :ttTransactionTest, :all, fn test, test_subset, test_name, %{homestead_filler: filler} ->
    trx_data = test["transaction"]
    src_data = filler[test_name]
    transaction = (trx_data || src_data["transaction"]) |> load_trx

    if src_data["expect"] == "invalid" do
      # TODO: Include checks of "invalid" tests
      Logger.debug("Skipping invalid transaction test: TransactionTests/Homestead - #{test_subset} - #{test_name}")

      nil
    else
      assert transaction |> Transaction.serialize == test["rlp"] |> load_hex |> :binary.encode_unsigned |> ExRLP.decode

      if test["hash"], do: assert transaction |> Transaction.serialize |> ExRLP.encode |> BitHelper.kec == test["hash"] |> maybe_hex
      if test["sender"], do: assert Signature.sender(transaction) == {:ok, test["sender"] |> maybe_hex}
    end
  end

  # Test EIP155
  eth_test "TransactionTests/EIP155", :ttTransactionTestEip155VitaliksTests, :all, fn test, test_subset, test_name, %{eip155_filler: filler} ->
    trx_data = test["transaction"]
    src_data = filler[test_name]
    transaction = (trx_data || src_data["transaction"]) |> load_trx
    chain_id = 1

    if src_data["expect"] == "invalid" do
      # TODO: Include checks of "invalid" tests
      Logger.debug("Skipping invalid transaction test: TransactionTests/EIP555 - #{test_subset} - #{test_name}")

      nil
    else
      assert transaction |> Transaction.serialize == test["rlp"] |> load_hex |> :binary.encode_unsigned |> ExRLP.decode

      if test["hash"], do: assert transaction |> Transaction.serialize(chain_id) |> ExRLP.encode |> BitHelper.kec == test["hash"] |> maybe_hex
      if test["sender"], do: assert Signature.sender(transaction, chain_id) == {:ok, test["sender"] |> maybe_hex}
    end
  end

  describe "when handling transactions" do
    test "serialize and deserialize" do
      trx = %Transaction{nonce: 5, gas_price: 6, gas_limit: 7, to: <<1::160>>, value: 8, v: 27, r: 9, s: 10, data: "hi"}

      assert trx == trx |> Transaction.serialize |> ExRLP.encode |> ExRLP.decode |> Transaction.deserialize
    end

    test "for a transaction with a stop" do
      beneficiary = <<0x05::160>>
      private_key = <<1::256>>
      sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>> # based on simple private key
      contract_address = Blockchain.Contract.new_contract_address(sender, 6)
      machine_code = EVM.MachineCode.compile([:stop])
      trx = %Blockchain.Transaction{nonce: 5, gas_price: 3, gas_limit: 100_000, to: <<>>, value: 5, init: machine_code}
            |> Blockchain.Transaction.Signature.sign_transaction(private_key)

      {state, gas_used, logs} = MerklePatriciaTree.Trie.new(MerklePatriciaTree.Test.random_ets_db())
        |> Blockchain.Account.put_account(sender, %Blockchain.Account{balance: 400_000, nonce: 5})
        |> Blockchain.Transaction.execute_transaction(trx, %Block.Header{beneficiary: beneficiary})

      assert gas_used == 53004
      assert logs == ""
      assert Blockchain.Account.get_accounts(state, [sender, beneficiary, contract_address]) ==
        [
          %Blockchain.Account{balance: 240983, nonce: 6}, %Blockchain.Account{balance: 159012}, %Blockchain.Account{balance: 5}
        ]
    end
  end

  defp load_trx(trx_data) do
    to = trx_data["to"] |> maybe_address
    data = trx_data["data"] |> maybe_hex

    %Blockchain.Transaction{
      nonce: trx_data["nonce"] |> load_integer,
      gas_price: trx_data["gasPrice"] |> load_integer,
      gas_limit: trx_data["gasLimit"] |> load_integer,
      to: to,
      value: trx_data["value"] |> load_integer,
      v: trx_data["v"] |> load_integer,
      r: trx_data["r"] |> load_integer,
      s: trx_data["s"] |> load_integer,
      init: (if to == <<>>, do: data, else: <<>>),
      data: (if to == <<>>, do: <<>>, else: data)
    }
  end
end