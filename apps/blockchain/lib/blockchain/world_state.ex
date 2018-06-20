defmodule Blockchain.WorldState do
  @moduledoc """
  Repreents the world state, as defined in Section 4.1 of the Yellow Paper.
  """

  import ExthCrypto.Math, only: [bin_to_hex: 1]

  alias MerklePatriciaTree.Trie
  alias Blockchain.Account

  @doc """
  Dumps the world state to the stdout.
  """
  @spec dump(Trie.t()) :: no_return()
  def dump(state) do
    state
    |> Trie.Inspector.all_values()
    |> Enum.map(fn {key, value} ->
      k = bin_to_hex(key)
      v = value |> ExRLP.decode() |> Account.deserialize()
      {k, v}
    end)
    |> Enum.map(fn {address_key, account} ->
      IO.puts(address_key)
      IO.puts("  Balance: #{account.balance}")
      IO.puts("  Nonce: #{account.nonce}")
      IO.puts("  Storage Root:")
      IO.puts("  " <> bin_to_hex(account.storage_root))
      IO.puts("  Code Hash:")
      IO.puts("  " <> bin_to_hex(account.code_hash))
    end)
  end
end
