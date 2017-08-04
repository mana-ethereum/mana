defmodule Blockchain.BlocktreeTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Blocktree
  alias Blockchain.Blocktree

  test "multi-level tree" do
    block_10 = %Blockchain.Block{
      block_hash: <<10>>,
      header: %Blockchain.Block.Header{
        number: 5, parent_hash: <<>>, difficulty: 100}}
    block_20 = %Blockchain.Block{
      block_hash: <<20>>,
      header: %Blockchain.Block.Header{
        number: 6, parent_hash: <<10>>, difficulty: 110}}
    block_21 = %Blockchain.Block{
      block_hash: <<21>>,
      header: %Blockchain.Block.Header{
        number: 6, parent_hash: <<10>>, difficulty: 120}}
    block_30 = %Blockchain.Block{
      block_hash: <<30>>,
      header: %Blockchain.Block.Header{
        number: 7, parent_hash: <<20>>, difficulty: 120}}
    block_40 = %Blockchain.Block{
      block_hash: <<40>>,
      header: %Blockchain.Block.Header{
        number: 8, parent_hash: <<30>>, difficulty: 120}}

    tree =
      Blocktree.new_tree()
      |> Blocktree.add_block(block_10)
      |> Blocktree.add_block(block_20)
      |> Blocktree.add_block(block_21)
      |> Blocktree.add_block(block_30)
      |> Blocktree.add_block(block_40)

    assert Blocktree.inspect_tree(tree) ==
      [:root, [
        {5, <<10>>}, [
          {6, <<20>>}, [
            {7, <<30>>}, [
              {8, <<40>>}]
            ]
          ], [
          {6, <<21>>}
        ]
      ]
    ]
  end
end