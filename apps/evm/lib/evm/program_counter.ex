defmodule EVM.ProgramCounter do
  @moduledoc """
  Module for manipulating the program counter which keeps track
  of where we are in the contract code.

  Reffered to as `pc` in the Yellow Paper.
  """

  @doc """
  Increments the program counter

  ## Examples

      iex> EVM.ProgramCounter.next(9, EVM.Operation.metadata(:add), [1, 1])
      10
      iex> EVM.ProgramCounter.next(10, EVM.Operation.metadata(:push2), [1, 1])
      13
      iex> EVM.ProgramCounter.next(7, EVM.Operation.metadata(:jumpi), [1, 1])
      1
      iex> EVM.ProgramCounter.next(7, EVM.Operation.metadata(:jumpi), [1, 0])
      8
  """
  @spec next(integer(), Operation.Metadata.t, list(EVM.val)) :: MachineState.t
  def next(_current_position, %{sym: :jump}, [position]) do
    position
  end

  def next(current_position, %{sym: :jumpi}, [position, condition]) do
    if condition == 0 do
      current_position + 1
    else
      position
    end
  end

  def next(current_position, %{machine_code_offset: machine_code_offset} , _inputs) do
    current_position + machine_code_offset + 1
  end
end
