defmodule Blockchain.AccountTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Account
  alias Blockchain.Account

  test "serialize and deserialize" do
    acct = %Account{nonce: 5, balance: 10, storage_root: <<0x00, 0x01>>, code_hash: <<0x01, 0x02>>}

    assert acct == acct |> Account.serialize |> ExRLP.encode |> ExRLP.decode |> Account.deserialize
  end

  test "valid empty state_root" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)

    assert state.root_hash == <<86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47, 181, 227, 99, 180, 33>>
  end

  test "valid state_root with one empty account" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    state = state
      |> Blockchain.Account.put_account(<<0x01::160>>, %Blockchain.Account{
        nonce: 0,
        balance: 0,
        code_hash: <<>> |> BitHelper.kec(),
        storage_root: ExRLP.encode(<<>>) |> BitHelper.kec(),
      })

    assert state.root_hash == <<166, 181, 213, 15, 123, 60, 57, 185, 105, 194, 254, 143, 237, 9, 25, 57, 198, 116, 254, 244, 155, 72, 38, 48, 156, 182, 153, 67, 97, 227, 155, 113>>
  end

  test "valid state root with an updated storage value" do
    db = MerklePatriciaTree.Test.random_ets_db()
    address = <<0x01::160>>
    state = MerklePatriciaTree.Trie.new(db)
    state = state
      |> Blockchain.Account.put_account(address, %Blockchain.Account{
        nonce: 0,
        balance: 0,
        code_hash: <<>> |> BitHelper.kec(),
        storage_root: ExRLP.encode(<<>>) |> BitHelper.kec(),
      })
      |> Blockchain.Account.put_storage(address, 1, 1)

    assert state.root_hash == <<100, 231, 49, 195, 57, 235, 18, 88, 149, 202, 124, 230, 118, 223, 241, 190, 56, 214, 7, 199, 253, 154, 5, 187, 181, 217, 116, 222, 172, 24, 209, 217>>
  end

  test "valid state root for an account with code set" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    address = <<0x01::160>>
    state = state
      |> Blockchain.Account.put_account(address, %Blockchain.Account{
        nonce: 0,
        balance: 0,
        code_hash: <<>> |> BitHelper.kec(),
        storage_root: ExRLP.encode(<<>>) |> BitHelper.kec(),
      })
      |> Blockchain.Account.put_code(address, <<1, 2, 3>>)

    assert state.root_hash == <<57, 201, 95, 169, 186, 185, 65, 138, 89, 184, 108, 249, 63, 187, 179, 237, 59, 248, 230, 221, 33, 72, 223, 183, 87, 146, 198, 9, 43, 48, 48, 168>>
  end

  test "valid state root after nonce has been incremented" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    address = <<0x01::160>>
    state = state
      |> Blockchain.Account.put_account(address, %Blockchain.Account{
        nonce: 99,
        balance: 0,
        code_hash: <<>> |> BitHelper.kec(),
        storage_root: ExRLP.encode(<<>>) |> BitHelper.kec(),
      })
        |> Blockchain.Account.increment_nonce(address)

    assert state.root_hash == <<216, 110, 244, 57, 70, 173, 157, 118, 183, 112, 181, 20, 47, 193, 5, 3, 244, 142, 211, 183, 134, 195, 74, 102, 249, 240, 226, 192, 75, 163, 199, 197>>
  end

  test "valid state root with an account balance set" do
    db = MerklePatriciaTree.Test.random_ets_db()
    state = MerklePatriciaTree.Trie.new(db)
    address = <<0x01::160>>
    state = state
      |> Blockchain.Account.put_account(address, %Blockchain.Account{
        nonce: 0,
        balance: 10,
        code_hash: <<>> |> BitHelper.kec(),
        storage_root: ExRLP.encode(<<>>) |> BitHelper.kec(),
      })
        |> Blockchain.Account.add_wei(address, 10)

    assert state.root_hash == <<192, 238, 234, 193, 139, 21, 7, 152, 194, 188, 80, 192, 211, 109, 186, 215, 229, 222, 21, 222, 121, 230, 139, 179, 23, 132, 217, 128, 6, 17, 167, 54>>
  end
end
