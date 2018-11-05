defmodule ExthCrypto.Key do
  @moduledoc """
  Simple functions to interact with keys.
  """

  @type symmetric_key :: binary()
  @type public_key_der :: binary()
  @type public_key :: <<_::8, _::_*8>>
  @type private_key_der :: binary()
  @type private_key :: binary()
  @type key_pair :: {public_key, private_key}

  @doc """
  Converts a key from der to raw format.

  ## Examples

      iex> ExthCrypto.Key.der_to_raw(<<0x04, 0x01>>)
      <<0x01>>
  """
  @spec der_to_raw(public_key_der) :: public_key
  def der_to_raw(public_key_der) do
    <<0x04, public_key::binary()>> = public_key_der

    public_key
  end

  @doc """
  Converts a key from raw to der format.

  ## Examples

      iex> ExthCrypto.Key.der_to_raw(<<0x04, 0x01>>)
      <<0x01>>
  """
  @spec raw_to_der(public_key) :: public_key_der
  def raw_to_der(public_key) do
    <<0x04>> <> public_key
  end
end
