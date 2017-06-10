defmodule ExRLPTest do
  use ExUnit.Case

  test "encodes empty string" do
    string = ""
    expected_result = "80"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes byte string 00" do
    string =  "\u0000"
    expected_result = "00"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes byte string 01" do
    string = "\u0001"
    expected_result = "01"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes byte string 7f" do
    string = "\u007F"
    expected_result = "7f"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes short string (1)" do
    string = "dog"
    expected_result = "83646f67"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes short string (2)" do
    string = "Lorem ipsum dolor sit amet, consectetur adipisicing eli"
    expected_result = "b74c6f72656d20697073756d20646f6c6f722073697" <>
      "420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes long string (1)" do
    string = "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
    expected_result = "b8384c6f72656d20697073756d20646f6c6f722073697" <>
      "420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes long string (2)" do
    string = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " <>
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
      "metus ac ornare cursus, dolor justo ultrices metus, at ullamcorper volutpat"
    expected_result = "b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6" <>
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

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes zero" do
    string = 0
    expected_result = "80"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes small integer (1)" do
    string = 1
    expected_result = "01"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes small integer (2)" do
    string = 16
    expected_result = "10"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes small integer (3)" do
    string = 79
    expected_result = "4f"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes small integer (4)" do
    string = 127
    expected_result = "7f"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes medium integer (1)" do
    string = 128
    expected_result = "8180"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes medium integer (2)" do
    string = 1000
    expected_result = "8203e8"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes medium integer (3)" do
    string = 100000
    expected_result = "830186a0"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes medium integer (4)" do
    string = 83729609699884896815286331701780722
    expected_result = "8f102030405060708090a0b0c0d0e0f2"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes medium integer (5)" do
    string = 105315505618206987246253880190783558935785933862974822347068935681
    expected_result = "9c0100020003000400050006000700080009000a000b000c000d000e01"

    result = string |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes string list" do
    list = [ "dog", "god", "cat" ]
    expected_result = "cc83646f6783676f6483636174"

    result = list |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes multilist" do
    list = [ "zw", [ 4 ], 1 ]
    expected_result = "c6827a77c10401"

    result = list |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes max short list" do
    list = [ "asdf", "qwer", "zxcv", "asdf","qwer",
               "zxcv", "asdf", "qwer", "zxcv", "asdf", "qwer"]
    expected_result = "f784617364668471776572847a7863768461736466847" <>
      "1776572847a78637684617364668471776572847a78637684617364668471776572"

    result = list |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes long list (1)" do
    list = [
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"]
    ]
    expected_result = "f840cf84617364668471776572847a786376cf84617364668" <>
      "471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376"

    result = list |> ExRLP.encode

    assert result == expected_result
  end

  test "encodes long list (2)" do
    list = [
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"],
      ["asdf","qwer","zxcv"]
    ]
    expected_result = "f90200cf84617364668471776572847a786376cf" <>
      "84617364668471776572847a786376cf84617364668471776572847a" <>
      "786376cf84617364668471776572847a786376cf8461736466847177" <>
      "6572847a786376cf84617364668471776572847a786376cf84617364" <>
      "668471776572847a786376cf84617364668471776572847a786376cf" <>
      "84617364668471776572847a786376cf84617364668471776572847a" <>
      "786376cf84617364668471776572847a786376cf8461736466847177" <>
      "6572847a786376cf84617364668471776572847a786376cf84617364" <>
      "668471776572847a786376cf84617364668471776572847a786376cf" <>
      "84617364668471776572847a786376cf84617364668471776572847a" <>
      "786376cf84617364668471776572847a786376cf8461736466847177" <>
      "6572847a786376cf84617364668471776572847a786376cf84617364" <>
      "668471776572847a786376cf84617364668471776572847a786376cf" <>
      "84617364668471776572847a786376cf84617364668471776572847a" <>
      "786376cf84617364668471776572847a786376cf8461736466847177" <>
      "6572847a786376cf84617364668471776572847a786376cf84617364" <>
      "668471776572847a786376cf84617364668471776572847a786376cf" <>
      "84617364668471776572847a786376cf84617364668471776572847a" <>
      "786376cf84617364668471776572847a786376"

    result = list |> ExRLP.encode

    assert result == expected_result
  end
end
