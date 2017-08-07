defmodule ExDevp2p do
  @network_adapter Application.get_env(:ex_devp2p, :network_adapter)

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(@network_adapter, [ExDevp2p.Network])
    ]

    opts = [strategy: :one_for_one, name: ExDevp2p]
    Supervisor.start_link(children, opts)
  end

end