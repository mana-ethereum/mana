use Mix.Config

config :ex_wire,
  network_adapter: {ExWire.Adapter.UDP, NetworkClient},
  sync: false
