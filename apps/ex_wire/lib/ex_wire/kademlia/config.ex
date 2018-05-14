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

  @spec bucket_size() :: integer()
  def bucket_size do
    @bucket_size
  end

  @spec concurrency() :: integer()
  def concurrency do
    @concurrency
  end

  @spec id_size() :: integer()
  def id_size do
    @id_size
  end

  @spec bits_per_hop() :: integer()
  def bits_per_hop do
    @bits_per_hop
  end

  @spec eviction_check_interval() :: integer()
  def eviction_check_interval do
    @eviction_check_interval
  end

  @spec request_timeout() :: integer
  def request_timeout do
    @request_timeout
  end

  @spec bucket_refresh_interval() :: integer
  def bucket_refresh_interval do
    @bucket_refresh_interval
  end
end
