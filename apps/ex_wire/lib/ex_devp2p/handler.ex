defmodule ExDevp2p.Handler do
  @moduledoc """
  Defines a behavior for all message handlers of RLPx messages.

  Message handlers tell us how we should respond to a given incoming transmission,
  after it has been decoded.
  """

  alias ExDevp2p.Message
  alias ExDevp2p.Crypto

  require Logger

  @handlers %{
    0x01 => ExDevp2p.Handler.Ping,
    0x03 => ExDevp2p.Handler.FindNeighbors,
  }

  defmodule Params do
    @moduledoc "Struct to store parameters from an incoming message"

    defstruct [
      remote_host: nil,
      signature: nil,
      recovery_id: nil,
      hash: nil,
      data: nil,
    ]

    @type t :: %__MODULE__{
      remote_host: ExDevp2p.Encoding.Address.t,
      signature: Crpyto.signature,
      recovery_id: Crypto.recovery_id,
      hash: Cryto.hash,
      data: binary(),
    }
  end

  @type handler_response :: :not_implented | :no_response | Message.t
  @callback handle(Params.t) :: handler_response

  @doc """
  Decides which module to route the given message to,
  or returns `:not_implemented` if we have no implemented
  a handler for the message type.

  ## Examples

      iex> ExDevp2p.Handler.dispatch(0x01, %ExDevp2p.Handler.Params{})
      :pong

      iex> ExDevp2p.Handler.dispatch(0x99, %ExDevp2p.Handler.Params{})
      :not_implemented

      # TODO: Add a `no_response` test case
  """
  @spec dispatch(integer(), Params.t) :: handler_response
  def dispatch(type, params) do
    case @handlers[type] do
      mod when is_atom(mod) -> apply(mod, :handle, [params])
      _ ->
        Logger.warn("Message code `#{inspect type, base: :hex}` not implemented")
        :not_implemented
    end
  end

end