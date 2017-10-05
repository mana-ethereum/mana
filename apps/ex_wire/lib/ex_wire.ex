defmodule ExWire do
  @moduledoc """
  Main application for ExWire. We will begin listening on a port
  when this application is started.
  """

  @default_network_adapter Application.get_env(:ex_wire, :network_adapter)

  @type node_id :: binary()

  use Application

  def start(_type, args) do
    import Supervisor.Spec

    network_adapter = Keyword.get(args, :network_adapter, @default_network_adapter)
    port = Keyword.get(args, :port, ExWire.Config.listen_port())
    name = Keyword.get(args, :name, ExWire)

    children = [
      worker(network_adapter, [{ExWire.Network, []}, port])
    ]

    opts = [strategy: :one_for_one, name: name]
    Supervisor.start_link(children, opts)
  end

end