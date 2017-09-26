defmodule ExthCrypto do
  @moduledoc """
  Handles the general crypto stuff.
  """

  @type symmetric_key :: binary()
  @type public_key_der :: binary()
  @type public_key :: binary()
  @type private_key_der :: binary()
  @type private_key :: binary()

  @type curve :: nil
  @type curve_params :: nil

  # TODO: Doc and test
  @spec der_to_raw(public_key_der) :: public_key
  def der_to_raw(public_key_der) do
    <<0x04, public_key::binary()>> = public_key_der

    public_key
  end

  # TODO: Doc and test
  @spec raw_to_der(public_key) :: public_key_der
  def raw_to_der(public_key) do
    <<0x04>> <> public_key
  end
  
end
