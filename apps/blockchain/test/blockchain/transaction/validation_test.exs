defmodule Blockchain.Transaction.ValidationTest do
  use ExUnit.Case, async: true

  doctest Blockchain.Transaction.Validation

  alias MerklePatriciaTree.Trie
  alias EthCore.Block.Header
  alias Blockchain.{Transaction, Account}
  alias Blockchain.Transaction.{Validation, Signature}

  setup do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = Trie.new(db)
    private_key = <<1::256>>
    # based on simple private key
    sender = <<126, 95, 69, 82, 9, 26, 105, 18, 93, 93, 252, 183, 184, 194, 101, 144, 41, 57, 91, 223>>
    context = %{
      state: state,
      sender: sender,
      private_key: private_key
    }
    {:ok, context}
  end

  describe "validate/3" do
    test "sender address is nil", %{state: state} do
      tx = %Transaction{
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

      result = Validation.validate(state, tx, %Header{})

      assert result == {:invalid, :invalid_sender}
    end

    test "sender account is nil", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 1_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result = Validation.validate(ctx.state, tx, %Header{})

      assert result == {:invalid, :missing_account}
    end

    test "has sender account, but nonce mismatch", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 1_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 4,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 1000, nonce: 5})
        |> Validation.validate(tx, %Header{})

      assert result == {:invalid, :nonce_mismatch}
    end

    test "insufficient starting gas", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 1_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 1000, nonce: 5})
        |> Validation.validate(tx, %Header{})

      assert result == {:invalid, :insufficient_intrinsic_gas}
    end

    test "insufficient endowment", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 100_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 1000, nonce: 5})
        |> Validation.validate(tx, %Header{})

      assert result == {:invalid, :insufficient_balance}
    end

    test "insufficient balance", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 100_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 100_001, nonce: 5})
        |> Validation.validate(tx, %Header{})

      assert result == {:invalid, :insufficient_balance}
    end

    test "over gas limit", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 100_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 100_006, nonce: 5})
        |> Validation.validate(tx, %Header{gas_limit: 50_000, gas_used: 49_999})

      assert result == {:invalid, :over_gas_limit}
    end

    test "valid transaction", ctx do
      tx = %Transaction{
        data: <<>>,
        gas_limit: 100_000,
        gas_price: 1,
        init: <<1>>,
        nonce: 5,
        to: <<>>,
        value: 5
      }
      tx = Signature.sign_transaction(tx, ctx.private_key)

      result =
        ctx.state
        |> Account.put_account(ctx.sender, %Account{balance: 100_006, nonce: 5})
        |> Validation.validate(tx, %Header{gas_limit: 500_000, gas_used: 49_999})

      assert result == :valid
    end
  end
end
