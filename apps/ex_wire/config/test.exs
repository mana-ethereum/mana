use Mix.Config

config :ex_wire,
  network_adapter: ExWire.Adapter.Test,
  private_key: :binary.encode_unsigned(0xd772e3d6a001a38064dd23964dd2836239fa0e6cec8b28972a87460a17210fe9)
