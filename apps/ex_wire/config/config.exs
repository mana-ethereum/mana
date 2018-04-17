# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :ex_wire,
  p2p_version: 0x04,
  protocol_version: 63,
  network_id: 3, # ropsten
  caps: [{"eth", 62}, {"eth", 63}],
  chain: :ropsten,
  private_key: :random, # TODO: This should be set and stored in a file
  bootnodes: :from_chain,
  commitment_count: 1 # Number of peer advertisements before we trust a block

import_config "#{Mix.env}.exs"
