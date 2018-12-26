defmodule JSONRPC2.SpecHandler.CallRequestTest do
  use ExUnit.Case, async: true
  alias JSONRPC2.SpecHandler.CallRequest

  describe "new/1" do
    test "creates new CallRequest struct from input params" do
      params = %{
        "from" => "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
        "to" => "0x619f56e8bed07fe196c0dbc41b52e2bc64817b3a",
        "gas" => "0x07",
        "gas_price" => "0x06",
        "value" => "0x01"
      }

      result = CallRequest.new(params)

      assert result == %JSONRPC2.SpecHandler.CallRequest{
               data: nil,
               from:
                 <<97, 159, 86, 232, 190, 208, 127, 225, 150, 192, 219, 196, 27, 82, 226, 188,
                   100, 129, 123, 58>>,
               gas: 7,
               gas_price: 6,
               to:
                 <<97, 159, 86, 232, 190, 208, 127, 225, 150, 192, 219, 196, 27, 82, 226, 188,
                   100, 129, 123, 58>>,
               value: 1
             }
    end

    test "creates new CallRequest when map is empty" do
      params = %{}

      result = CallRequest.new(params)

      assert result == %JSONRPC2.SpecHandler.CallRequest{
               data: nil,
               from: nil,
               gas: nil,
               gas_price: nil,
               to: nil,
               value: nil
             }
    end
  end
end
