defmodule Blockchain.Transaction.ValidityTest do
  use ExUnit.Case, async: true
  alias Blockchain.Transaction.Validity
  alias Blockchain.{Transaction, Account}

  describe "validate/3" do
    test "invalidates transaction when sender address is nil" do
      trx = %Transaction{
        data: <<>>,
        gas_limit: 1_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5,
        r: 1,
        s: 2,
        v: 3
      }

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Validity.validate(trx, %Block.Header{}, EVM.Configuration.FrontierTest.new())

      assert result == {:invalid, :invalid_sender}
    end

    test "invalidates transaction when sender account is nil" do
      private_key = <<1::256>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 1_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 5,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Validity.validate(trx, %Block.Header{}, EVM.Configuration.FrontierTest.new())

      assert result == {:invalid, :missing_account}
    end

    test "invalidates account when nonce mismatch" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 1_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 4,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 1000, nonce: 5})
        |> Validity.validate(trx, %Block.Header{}, EVM.Configuration.FrontierTest.new())

      assert result ==
               {:invalid,
                [
                  :over_gas_limit,
                  :insufficient_balance,
                  :insufficient_intrinsic_gas,
                  :nonce_mismatch
                ]}
    end

    test "invalidates account when insufficient starting gas" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 1_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 5,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 1000, nonce: 5})
        |> Validity.validate(trx, %Block.Header{}, EVM.Configuration.FrontierTest.new())

      assert result ==
               {:invalid, [:over_gas_limit, :insufficient_balance, :insufficient_intrinsic_gas]}
    end

    test "invalidates account when insufficient endowment" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 100_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 5,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 1000, nonce: 5})
        |> Validity.validate(trx, %Block.Header{}, EVM.Configuration.FrontierTest.new())

      assert result == {:invalid, [:over_gas_limit, :insufficient_balance]}
    end

    test "invalidates account when tranaction gas limit exceeds header gas limit" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 100_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 5,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 100_006, nonce: 5})
        |> Validity.validate(
          trx,
          %Block.Header{gas_limit: 50_000, gas_used: 49_999},
          EVM.Configuration.FrontierTest.new()
        )

      assert result == {:invalid, [:over_gas_limit]}
    end

    test "validates account" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 100_000,
          gas_price: 1,
          init: <<1>>,
          nonce: 5,
          to: <<>>,
          value: 5
        }
        |> Transaction.Signature.sign_transaction(private_key)

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 100_006, nonce: 5})
        |> Validity.validate(
          trx,
          %Block.Header{gas_limit: 500_000, gas_used: 49_999},
          EVM.Configuration.FrontierTest.new()
        )

      assert result == :valid
    end
  end
end
