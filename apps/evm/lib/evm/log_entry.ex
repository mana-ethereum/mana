defmodule EVM.LogEntry do
  @moduledoc """
  This module contains functions to work with logs.
  """

  defstruct address: nil, topics: [], data: nil

  @type t :: %__MODULE__{
          address: EVM.address(),
          topics: [integer()],
          data: binary()
        }

  def new(address, topics, data) do
    %__MODULE__{
      address: address,
      topics: topics,
      data: data
    }
  end
end
