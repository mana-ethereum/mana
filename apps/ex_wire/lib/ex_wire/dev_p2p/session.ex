defmodule ExWire.DEVp2p.Session do
  @moduledoc """
    Module to hold struct for a DEVp2p Wire Protocol session.
    The session should be active when `Hello` messages have been exchanged.

    See https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol#session-management
  """

  alias ExWire.Packet.Hello

  @type handshake_status :: boolean | Hello.t()
  @type t :: %__MODULE__{
          hello_sent: handshake_status,
          hello_received: handshake_status
        }

  defstruct hello_sent: false, hello_received: false

  @doc """
  Checks whether or not the session is active.

  A session is only active if the handshake is complete and if there are overlapping capabilities, meaning
  that some of the sub-protocols are the same (e.g. eth 62)

  ## Examples

      iex> hello_received = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> hello_sent = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> ExWire.DEVp2p.Session.active?(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: hello_sent})
      true
  """
  @spec active?(t) :: boolean()
  def active?(%__MODULE__{hello_received: false}), do: false
  def active?(%__MODULE__{hello_sent: false}), do: false

  def active?(session = %__MODULE__{hello_sent: %Hello{}, hello_received: %Hello{}}) do
    compatible_capabilities?(session)
  end

  @spec disconnect(t) :: Session.t()
  def disconnect(session = %__MODULE__{}) do
    %{session | hello_sent: false, hello_received: false}
  end

  @spec compatible_capabilities?(t) :: boolean()
  def compatible_capabilities?(session = %__MODULE__{}) do
    %__MODULE__{hello_received: hello_received, hello_sent: hello_sent} = session

    intersection =
      MapSet.intersection(
        to_mapset(hello_received.caps),
        to_mapset(hello_sent.caps)
      )

    !Enum.empty?(intersection)
  end

  @spec to_mapset(list()) :: MapSet.t()
  defp to_mapset(list) do
    Enum.into(list, MapSet.new())
  end
end
