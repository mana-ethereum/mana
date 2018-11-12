defmodule JSONRPC2.SpecHandler do
  use JSONRPC2.Server.Handler

  def handle_request("web3_clientVersion", _), do: "Mana 0.0.1"
end
