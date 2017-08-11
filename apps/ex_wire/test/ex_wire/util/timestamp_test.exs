defmodule ExWire.Util.TimestampTest do
  use ExUnit.Case, async: true
  alias ExWire.Util.Timestamp

  test "returns a valid timestamp" do
    assert Timestamp.now > 0
  end
end