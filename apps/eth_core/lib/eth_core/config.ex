defmodule EthCore.Config do
  @moduledoc """
  This module contains general configuration settings.
  """

  @word_size_in_bytes 4
  @byte_size 8
  @int_size 256
  @max_int round(:math.pow(2, @int_size))

  @doc """
  Returns maximum allowed integer size.
  """
  def max_int(), do: @max_int
  def int_size(), do: @int_size
  def byte_size(), do: @byte_size

  @doc """
  Returns word size in bits.
  """
  def word_size(), do: @word_size_in_bytes * @byte_size
end
