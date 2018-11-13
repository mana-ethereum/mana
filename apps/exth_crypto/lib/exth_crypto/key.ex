defmodule ExthCrypto.Key do
  @moduledoc """
  Simple functions to interact with keys.
  """

  @type symmetric_key :: binary()
  @type public_der_encoded_key_material :: <<_::16, _::_*8>>
  @type public_key_der :: {:public_der, public_der_encoded_key_material()}
  @type public_key :: <<_::8, _::_*8>>

  @type private_key :: <<_::8, _::_*8>>

  @type key_pair :: {public_key(), private_key()}

  @spec public_der_key(public_der_encoded_key_material()) :: public_key_der()
  def public_der_key(der = <<0x04, _::binary()>>) do
    {:public_der, der}
  end

  @doc """
  Converts a key from der to raw format.

  ## Examples

      iex> ExthCrypto.Key.public_der_to_raw({:public_der, <<0x04, 0x01>>})
      <<0x01>>
  """
  @spec public_der_to_raw(public_key_der()) :: public_key()
  def public_der_to_raw({:public_der, <<0x04, public_key::binary()>>}) do
    public_key
  end

  @doc """
  Converts a key from raw to der format.

  ## Examples

      iex> ExthCrypto.Key.public_raw_to_der(<<0x01>>)
      {:public_der, <<0x04, 0x01>>}
  """
  @spec public_raw_to_der(public_key()) :: public_key_der()
  def public_raw_to_der(public_key) do
    {:public_der, <<0x04>> <> public_key}
  end
end
