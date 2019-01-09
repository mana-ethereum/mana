defmodule Blockchain.Transaction.ValidityTest do
  use ExUnit.Case, async: true
  alias Blockchain.Transaction.Validity
  alias Blockchain.{Account, Chain, Transaction}

  describe "validate/3" do
    test "invalidates transaction when signature's s-value is too high (after homestead fork)" do
      trx = %Transaction{
        data: <<>>,
        gas_limit: 1_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5,
        r: 1,
        s: Transaction.Signature.secp256k1n_2() + 1,
        v: 27
      }

      result =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Validity.validate(
          trx,
          %Block.Header{},
          Chain.test_config("Homestead")
        )

      assert result == {:invalid, :invalid_sender}
    end

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
        |> Validity.validate(trx, %Block.Header{}, Chain.test_config("Frontier"))

      assert result == {:invalid, :invalid_sender}
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

      {:invalid, errors} =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 1000, nonce: 5})
        |> Validity.validate(trx, %Block.Header{}, Chain.test_config("Frontier"))

      assert Enum.member?(errors, :nonce_mismatch)
    end

    test "doesn't invalidate account when nonces mismatch but transaction hash `from` field" do
      private_key = <<1::256>>
      # based on simple private key
      sender =
        <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>

      trx =
        %Transaction{
          data: <<>>,
          gas_limit: 10_000_000,
          gas_price: 0,
          init: <<1>>,
          nonce: 4,
          to: <<>>,
          value: 5,
          from:
            <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91,
              223>>
        }
        |> Transaction.Signature.sign_transaction(private_key)

      {:invalid, errors} =
        MerklePatriciaTree.Test.random_ets_db()
        |> MerklePatriciaTree.Trie.new()
        |> Account.put_account(sender, %Account{balance: 1000, nonce: 5})
        |> Validity.validate(trx, %Block.Header{}, Chain.test_config("Frontier"))

      assert !Enum.member?(errors, :nonce_mismatch)
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
        |> Validity.validate(trx, %Block.Header{}, Chain.test_config("Frontier"))

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
        |> Validity.validate(trx, %Block.Header{}, Chain.test_config("Frontier"))

      assert result == {:invalid, [:over_gas_limit, :insufficient_balance]}
    end

    test "invalidates account when transaction gas limit exceeds header gas limit" do
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
          Chain.test_config("Frontier")
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
          Chain.test_config("Frontier")
        )

      assert result == :valid
    end
  end
end
