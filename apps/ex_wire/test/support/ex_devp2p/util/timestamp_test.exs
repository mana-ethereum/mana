defmodule ExDevp2p.Util.TimestampTest do
  use ExUnit.Case, async: true
  alias ExDevp2p.Util.Timestamp

  test "returns a valid timestamp" do
    assert Timestamp.now > 0
  end
end