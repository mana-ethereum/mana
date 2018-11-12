defmodule JSONRPC2.SpecHandlerTest do
  @moduledoc false

  use JSONRPC2.Server.Handler

  def handle_request("subtract", [x, y]) do
    x - y
  end

  def handle_request("subtract", %{"minuend" => x, "subtrahend" => y}) do
    x - y
  end

  def handle_request("update", _) do
    :ok
  end

  def handle_request("sum", numbers) do
    Enum.sum(numbers)
  end

  def handle_request("get_data", []) do
    ["hello", 5]
  end
end

defmodule JSONRPC2.ErrorHandlerTest do
  @moduledoc false
  use JSONRPC2.Server.Handler

  def handle_request("exit", []) do
    exit(:no_good)
  end

  def handle_request("raise", []) do
    raise "no good"
  end

  def handle_request("throw", []) do
    throw(:no_good)
  end

  def handle_request("bad_reply", []) do
    make_ref()
  end

  def handle_request("method_not_found", []) do
    throw(:method_not_found)
  end

  def handle_request("invalid_params", params) do
    throw({:invalid_params, params})
  end

  def handle_request("custom_error", []) do
    throw({:jsonrpc2, 404, "Custom not found error"})
  end

  def handle_request("custom_error", other) do
    throw({:jsonrpc2, 404, "Custom not found error", other})
  end
end

defmodule JSONRPC2.BuggyHandlerTest do
  @moduledoc false

  use JSONRPC2.Server.Handler

  @dialyzer [:no_return, :no_opaque]

  def handle_request("raise_function_clause_error", []) do
    String.contains?(5, 5)
  end
end
