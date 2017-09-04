defmodule Blockchain.BlocktreeTest do
  use ExUnit.Case, async: true
  doctest Blockchain.Blocktree
  alias Blockchain.Blocktree

  test "multi-level tree" do
    block_10 = %Blockchain.Block{
      block_hash: <<10>>,
      header: %Block.Header{
        number: 0, parent_hash: <<0::256>>, difficulty: 100}}
    block_20 = %Blockchain.Block{
      block_hash: <<20>>,
      header: %Block.Header{
        number: 1, parent_hash: <<10>>, difficulty: 110}}
    block_21 = %Blockchain.Block{
      block_hash: <<21>>,
      header: %Block.Header{
        number: 1, parent_hash: <<10>>, difficulty: 120}}
    block_30 = %Blockchain.Block{
      block_hash: <<30>>,
      header: %Block.Header{
        number: 2, parent_hash: <<20>>, difficulty: 120}}
    block_40 = %Blockchain.Block{
      block_hash: <<40>>,
      header: %Block.Header{
        number: 3, parent_hash: <<30>>, difficulty: 120}}

    tree =
      Blocktree.new_tree()
      |> Blocktree.add_block(block_10)
      |> Blocktree.add_block(block_20)
      |> Blocktree.add_block(block_21)
      |> Blocktree.add_block(block_30)
      |> Blocktree.add_block(block_40)

    assert Blocktree.inspect_tree(tree) ==
      [:root, [
        {0, <<10>>}, [
          {1, <<20>>}, [
            {2, <<30>>}, [
              {3, <<40>>}]
            ]
          ], [
          {1, <<21>>}
        ]
      ]
    ]
  end
end