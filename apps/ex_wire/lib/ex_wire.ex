defmodule ExWire do
  @moduledoc """
  Main application for ExWire
  """

  @network_adapter Application.get_env(:ex_wire, :network_adapter)
  @private_key Application.get_env(:ex_wire, :private_key)

  @type node_id :: binary()

  use Application

  @doc """
  Returns a private key that is generated when a new session is created. It is
  intended that this key is semi-persisted.
  """
  @spec private_key() :: binary()
  def private_key, do: @private_key

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(@network_adapter, [ExWire.Network])
    ]

    opts = [strategy: :one_for_one, name: ExWire]
    Supervisor.start_link(children, opts)
  end

end