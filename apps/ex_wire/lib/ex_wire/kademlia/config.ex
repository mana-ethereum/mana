defmodule ExWire.Kademlia.Config do
  @moduledoc """
  Contains params related to Kademlia algorithm.

  https://pdos.csail.mit.edu/~petar/papers/maymounkov-kademlia-lncs.pdf
  """

  # k
  @bucket_size 16

  # alpha
  @concurrency 3

  # key size. 0 <= i < @id_size - number of buckets
  @id_size 256

  # b
  @bits_per_hop 8

  # in ms
  @eviction_check_interval 75

  # in ms
  @request_timeout 300

  # in s
  @bucket_refresh_interval 3600

  @spec bucket_size() :: unquote(@bucket_size)
  def bucket_size, do: @bucket_size

  @spec concurrency() :: unquote(@concurrency)
  def concurrency, do: @concurrency

  @spec id_size() :: unquote(@id_size)
  def id_size, do: @id_size

  @spec bits_per_hop() :: unquote(@bits_per_hop)
  def bits_per_hop, do: @bits_per_hop

  @spec eviction_check_interval() :: unquote(@eviction_check_interval)
  def eviction_check_interval, do: @eviction_check_interval

  @spec request_timeout() :: unquote(@request_timeout)
  def request_timeout, do: @request_timeout

  @spec bucket_refresh_interval() :: unquote(@bucket_refresh_interval)
  def bucket_refresh_interval, do: @bucket_refresh_interval
end
