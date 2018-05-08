defmodule ExWire.KademliaConfig do
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

  @spec bucket_size() :: integer()
  def bucket_size do
    @bucket_size
  end

  @spec id_size() :: integer()
  def id_size do
    @id_size
  end
end
