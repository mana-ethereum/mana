defmodule ExthCrypto.Hash.Fake do
  @moduledoc """
  Simple fake hash that basically just returns its own input.

  Gasp, that's reversable!
  """

  @type fake_mac :: {:fake_mac, binary()}

  @doc """
  Initializes a new Fake mac stream.

  ## Examples

      iex> fake_mac = ExthCrypto.Hash.Fake.init_mac("abc")
      iex> is_nil(fake_mac)
      false
  """
  @spec init_mac(binary()) :: fake_mac
  def init_mac(initial) do
    {:fake_mac, initial}
  end

  @doc """
  Updates a given Fake mac stream, which is, do nothing.

  ## Examples

      iex> fake_mac = ExthCrypto.Hash.Fake.init_mac("init")
      ...> |> ExthCrypto.Hash.Fake.update_mac("data")
      iex> is_nil(fake_mac)
      false
  """
  @spec update_mac(fake_mac, binary()) :: fake_mac
  def update_mac({:fake_mac, mac}, _data) do
    {:fake_mac, mac}
  end

  @doc """
  Finalizes a given Fake mac stream to produce the current
  hash.

  ## Examples

      iex> ExthCrypto.Hash.Fake.init_mac("abc")
      ...> |> ExthCrypto.Hash.Fake.update_mac("def")
      ...> |> ExthCrypto.Hash.Fake.final_mac()
      "abc"
  """
  @spec final_mac(fake_mac) :: binary()
  def final_mac({:fake_mac, mac}) do
    mac
  end
end
