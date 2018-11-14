defmodule JSONRPC2.ResponseTest do
  use ExUnit.Case, async: true
  alias alias JSONRPC2.Response

  test "correct request deserialization" do
    request = ~S({"id":1,"jsonrpc":"2.0","result":"some_result"})
    assert Response.deserialize_response(request) == {:ok, {1, {:ok, "some_result"}}}

    request = ~S({"id":1,"jsonrpc":"2.0","method":"some_result"})

    assert Response.deserialize_response(request) ==
             {:error,
              {:invalid_response, %{"id" => 1, "jsonrpc" => "2.0", "method" => "some_result"}}}

    request = ~S({"id":1,"jsonrpc":"2.0","result":55})
    assert Response.deserialize_response(request) == {:ok, {1, {:ok, 55}}}

    assert Response.id_and_response(%{"jsonrpc" => "2.0", "id" => 42, "result" => "result"}) ==
             {:ok, {42, {:ok, "result"}}}

    assert Response.id_and_response(%{
             "jsonrpc" => "2.0",
             "id" => 42,
             "error" => %{"code" => 1, "message" => "something isn't right", "data" => []}
           }) == {:ok, {42, {:error, {1, "something isn't right", []}}}}
  end
end
