defmodule JSONRPC2.SpecHandler do
  use JSONRPC2.Server.Handler

  def handle_request("web3_clientVersion", _), do: Application.get_env(:jsonrpc2, :mana_version)
end
