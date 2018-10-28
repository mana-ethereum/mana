defmodule CLI.Sync.RPCTest do
  use ExUnit.Case, async: true
  doctest CLI.Sync.RPC
  alias CLI.Sync.RPC

  describe "setup/1" do
    test "starts ethereumex" do
      RPC.setup("http://test.com")

      assert is_started?(:ethereumex) == true
    end

    test "with an http url" do
      assert RPC.setup("http://test.com") == {:ok, Ethereumex.HttpClient}
    end

    test "with an https url" do
      assert RPC.setup("https://test.com") == {:ok, Ethereumex.HttpClient}
    end

    test "with an ipc url" do
      assert RPC.setup("ipc:///some/file/path") == {:ok, Ethereumex.IpcClient}
    end

    test "with an invalid url" do
      assert RPC.setup("abc") == {
               :error,
               "Unknown scheme for %URI{authority: nil, fragment: nil, host: nil, path: \"abc\", port: nil, query: nil, scheme: nil, userinfo: nil}"
             }
    end
  end

  @spec is_started?(atom()) :: boolean()
  defp is_started?(app_name) do
    Enum.any?(Application.started_applications(), fn {app, _, _} -> app == app_name end)
  end
end
