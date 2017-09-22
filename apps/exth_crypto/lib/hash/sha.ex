defmodule ExCrypto.SHA do
  @moduledoc """
  Helper functions for running Secure Hash Algorithm (SHA).
  """

  @doc """
  Runs the SHA-1 algorithm.

  ## Examples

      iex> ExCrypto.SHA.sha1("test")
      <<>>
  """
  @type sha1(binary()) :: binary()
  def sha1(data) do
    :crypto.hash(:sha, data)
  end
end