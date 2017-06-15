defmodule ExRLP.DecoderTest do
  use ExUnit.Case
  alias ExRLP.Decoder

  test "decodes empty string" do
    rlp_binary = "80"
    expected_result = [""]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 00" do
    rlp_binary = "00"
    expected_result = ["\u0000"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 01" do
    rlp_binary = "01"
    expected_result = ["\u0001"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes byte string 7f" do
    rlp_binary = "7f"
    expected_result = ["\u007F"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes short string (1)" do
    rlp_binary = "83646f67"
    expected_result = ["dog"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes short string (2)" do
    rlp_binary = "b74c6f72656d20697073756d20646f6c6f722073697" <>
      "420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"
    expected_result = ["Lorem ipsum dolor sit amet, consectetur adipisicing eli"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes long string (1)" do
    rlp_binary = "b8384c6f72656d20697073756d20646f6c6f722073697" <>
      "420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"
    expected_result = ["Lorem ipsum dolor sit amet, consectetur adipisicing elit"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes long string (2)" do
    rlp_binary = "b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6" <>
      "e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d61757269" <>
      "73206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c6" <>
      "97320666175636962757320746f72746f722e2050726f696e20737573636970697420756c7472696369" <>
      "6573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756" <>
      "973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920" <>
      "612065737420696d70657264696574206d6920756c6c616d636f7270657220616c69717565742073757" <>
      "36369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c20" <>
      "76756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756" <>
      "c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e61" <>
      "20636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d65747" <>
      "5732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f" <>
      "6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d6973206" <>
      "96e206661756369627573206f726369206c756374757320657420756c74726963657320706f73756572" <>
      "6520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656" <>
      "d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074" <>
      "656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e206" <>
      "17563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c" <>
      "697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656" <>
      "c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d" <>
      "657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f722074726973746" <>
      "97175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e746572" <>
      "64756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6" <>
      "e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20" <>
      "756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174"
    expected_result = ["Lorem ipsum dolor sit amet, consectetur adipiscing elit. " <>
      "Curabitur mauris magna, suscipit sed vehicula non, iaculis faucibus " <>
      "tortor. Proin suscipit ultricies malesuada. Duis tortor elit, dictum " <>
      "quis tristique eu, ultrices at risus. Morbi a est imperdiet mi ullamcorper " <>
      "aliquet suscipit nec lorem. Aenean quis leo mollis, vulputate elit varius, " <>
      "consequat enim. Nulla ultrices turpis justo, et posuere urna consectetur " <>
      "nec. Proin non convallis metus. Donec tempor ipsum in mauris congue " <>
      "sollicitudin. Vestibulum ante ipsum primis in faucibus orci luctus et " <>
      "ultrices posuere cubilia Curae; Suspendisse convallis sem vel massa faucibus" <>
      ", eget lacinia lacus tempor. Nulla quis ultricies purus. Proin auctor rhoncus " <>
      "nibh condimentum mollis. Aliquam consequat enim at metus luctus, a eleifend " <>
      "purus egestas. Curabitur at nibh metus. Nam bibendum, neque at auctor tristique, " <>
      "lorem libero aliquet arcu, non interdum tellus lectus sit amet eros. Cras rhoncus, " <>
      "metus ac ornare cursus, dolor justo ultrices metus, at ullamcorper volutpat"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  # test "decodes zero" do
  #   rlp_binary = "80"
  #   expected_result = 0

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes small integer (1)" do
  #   rlp_binary = "01"
  #   expected_result = 1

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes small integer (2)" do
  #   rlp_binary = "10"
  #   expected_result = 16

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes small integer (3)" do
  #   rlp_binary = "4f"
  #   expected_result = 79

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes small integer (4)" do
  #   rlp_binary = "7f"
  #   expected_result = 127

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes medium integer (1)" do
  #   rlp_binary = "8180"
  #   expected_result = 128

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes medium integer (2)" do
  #   rlp_binary = "8203e8"
  #   expected_result = 1000

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes medium integer (3)" do
  #   rlp_binary = "830186a0"
  #   expected_result = 100000

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes medium integer (4)" do
  #   rlp_binary = "8f102030405060708090a0b0c0d0e0f2"
  #   expected_result = 83729609699884896815286331701780722

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  # test "decodes medium integer (5)" do
  #   rlp_binary = "9c0100020003000400050006000700080009000a000b000c000d000e01"
  #   expected_result = 105315505618206987246253880190783558935785933862974822347068935681

  #   result = rlp_binary |> Decoder.decode(:integer)

  #   assert result == expected_result
  # end

  test "decodes string list" do
    rlp_binary = "cc83646f6783676f6483636174"
    expected_result = [ "dog", "god", "cat" ]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  test "decodes max short list" do
    rlp_binary = "f784617364668471776572847a7863768461736466847" <>
      "1776572847a78637684617364668471776572847a78637684617364668471776572"
    expected_result = [ "asdf", "qwer", "zxcv", "asdf","qwer",
                        "zxcv", "asdf", "qwer", "zxcv", "asdf", "qwer"]

    result = rlp_binary |> Decoder.decode

    assert result == expected_result
  end

  # test "encodes long list (2)" do
  #   rlp_binary = "f90200cf84617364668471776572847a786376cf" <>
  #     "84617364668471776572847a786376cf84617364668471776572847a" <>
  #     "786376cf84617364668471776572847a786376cf8461736466847177" <>
  #     "6572847a786376cf84617364668471776572847a786376cf84617364" <>
  #     "668471776572847a786376cf84617364668471776572847a786376cf" <>
  #     "84617364668471776572847a786376cf84617364668471776572847a" <>
  #     "786376cf84617364668471776572847a786376cf8461736466847177" <>
  #     "6572847a786376cf84617364668471776572847a786376cf84617364" <>
  #     "668471776572847a786376cf84617364668471776572847a786376cf" <>
  #     "84617364668471776572847a786376cf84617364668471776572847a" <>
  #     "786376cf84617364668471776572847a786376cf8461736466847177" <>
  #     "6572847a786376cf84617364668471776572847a786376cf84617364" <>
  #     "668471776572847a786376cf84617364668471776572847a786376cf" <>
  #     "84617364668471776572847a786376cf84617364668471776572847a" <>
  #     "786376cf84617364668471776572847a786376cf8461736466847177" <>
  #     "6572847a786376cf84617364668471776572847a786376cf84617364" <>
  #     "668471776572847a786376cf84617364668471776572847a786376cf" <>
  #     "84617364668471776572847a786376cf84617364668471776572847a" <>
  #     "786376cf84617364668471776572847a786376"
  #   expected_result = [
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"],
  #     ["asdf","qwer","zxcv"]
  #   ]

  #   result = rlp_binary |> Decoder.decode

  #   assert result == expected_result
  # end
end
