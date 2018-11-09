defmodule ExWire.DEVp2p.Session do
  @moduledoc """
  Module to hold struct for a DEVp2p Wire Protocol session.
  The session should be active when `Hello` messages have been exchanged.

  See https://github.com/ethereum/wiki/wiki/%C3%90%CE%9EVp2p-Wire-Protocol#session-management
  """

  alias ExWire.Packet.Hello

  @type t :: %__MODULE__{
          hello_sent: Hello.t() | nil,
          hello_received: Hello.t() | nil
        }

  defstruct hello_sent: nil,
            hello_received: nil

  @doc """
  Checks whether or not the session is active.

  A session is only active if the handshake is complete and if there are overlapping capabilities, meaning
  that some of the sub-protocols are the same (e.g. eth 62)

  ## Examples

      iex> hello_received = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> hello_sent = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> ExWire.DEVp2p.Session.active?(%ExWire.DEVp2p.Session{hello_received: nil, hello_sent: hello_sent})
      false
      iex> ExWire.DEVp2p.Session.active?(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: nil})
      false
      iex> ExWire.DEVp2p.Session.active?(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: hello_sent})
      true
  """
  @spec active?(t) :: boolean()
  def active?(%__MODULE__{hello_received: nil}), do: false
  def active?(%__MODULE__{hello_sent: nil}), do: false

  def active?(session = %__MODULE__{hello_sent: %Hello{}, hello_received: %Hello{}}) do
    compatible_capabilities?(session)
  end

  @doc """
  Marks a session as disconnected, which simply wipes our hello messages.

  ## Examples

      iex> hello_received = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> hello_sent = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> ExWire.DEVp2p.Session.disconnect(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: hello_sent})
      %ExWire.DEVp2p.Session{hello_sent: nil, hello_received: nil}
  """
  @spec disconnect(t) :: Session.t()
  def disconnect(session = %__MODULE__{}) do
    %{session | hello_sent: nil, hello_received: nil}
  end

  @doc """
  Determines if we have an intersection of capabilities between ourselves and
  a peer based on the caps listed in the hello messages.

  ## Examples

      iex> hello_received = %ExWire.Packet.Hello{caps: [{"eth", 62}, {"mana", 14}]}
      iex> hello_sent = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> ExWire.DEVp2p.Session.compatible_capabilities?(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: hello_sent})
      true

      iex> hello_received = %ExWire.Packet.Hello{caps: [{"eth", 63}]}
      iex> hello_sent = %ExWire.Packet.Hello{caps: [{"eth", 62}]}
      iex> ExWire.DEVp2p.Session.compatible_capabilities?(%ExWire.DEVp2p.Session{hello_received: hello_received, hello_sent: hello_sent})
      false
  """
  @spec compatible_capabilities?(t) :: boolean()
  def compatible_capabilities?(%__MODULE__{hello_received: hello_received, hello_sent: hello_sent}) do
    intersection =
      MapSet.intersection(
        to_mapset(hello_received.caps),
        to_mapset(hello_sent.caps)
      )

    Enum.any?(intersection)
  end

  @spec to_mapset(list()) :: MapSet.t()
  defp to_mapset(list) do
    Enum.into(list, MapSet.new())
  end
end
