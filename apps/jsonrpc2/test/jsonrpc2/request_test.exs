defmodule JSONRPC2.RequestTest do
  use ExUnit.Case, async: true
  alias JSONRPC2.Request

  test "correct request serialization" do
    params = [1, 2, 3]
    id = 0

    assert Request.serialized_request({"some_method", params, id}) ==
             {:ok, "{\"id\":0,\"jsonrpc\":\"2.0\",\"method\":\"some_method\",\"params\":[1,2,3]}"}

    params = []
    id = 1

    assert Request.serialized_request({"some_method", params, id}) ==
             {:ok, "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"some_method\",\"params\":[]}"}

    assert Request.request({"some_method", params}) ==
             %{"jsonrpc" => "2.0", "method" => "some_method", "params" => []}

    params = [1, 2, 3]
    id = 0

    assert Request.request({"some_method", params, id}) ==
             %{"id" => 0, "jsonrpc" => "2.0", "method" => "some_method", "params" => [1, 2, 3]}
  end
end
