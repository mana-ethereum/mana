defmodule EVM.Memory do
  @moduledoc """
  Functions to help us handle memory operations
  in the MachineState of the VM.
  """

  alias EVM.MachineState

  @type t :: binary()

  @doc """
  Reads a word out of memory, and also decides whether or not
  we should increment number of active words in our machine state.

  ## Examples

      iex> EVM.Memory.read(%EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 0}, 0, 0)
      {<<>>, %EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 0}}

      iex> EVM.Memory.read(%EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 0}, 0, 30)
      {<<0::240>>, %EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 1}}

      iex> EVM.Memory.read(%EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 0}, 0, 35)
      {<<1::256, 0::24>>, %EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 2}}

      iex> EVM.Memory.read(%EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 0}, 32, 35)
      {<<2::256, 0::24>>, %EVM.MachineState{memory: <<1::256, 2::256, 3::256, 4::256>>, active_words: 3}}

      iex> EVM.Memory.read(%EVM.MachineState{memory: <<1::256>>, active_words: 0}, 0, 35)
      {<<1::256, 0::24>>, %EVM.MachineState{memory: <<1::256>>, active_words: 2}}
  """
  @spec read(MachineState.t, EVM.val, EVM.val) :: {binary(), MachineState.t}
  def read(machine_state, offset, bytes) do
    data = read_zeroed_memory(machine_state.memory, offset, bytes)

    {data, machine_state |> MachineState.maybe_set_active_words(get_active_words(offset + bytes))}
  end

  @doc """
  Writes data to memory, and also decides whether or not
  we should increment number of active words in our machine state.

  Note: we will fill in zeros if the memory extends beyond our previous memory
  bounds. This could (very easily) overflow our memory by making a single byte
  write to a far-away location. The gas might be high, but it's still not desirable
  to have a system crash. The easiest mitigation will likely be to load in pages of
  memory as needed. These pages could have an offset and thus a far away page will
  only add a few bytes of memory.

  For now, we'll simply extend our memory and perform a simple write operation.

  Note: we also may just use a different data structure all-together for this.

  ## Examples

      iex> EVM.Memory.write(%EVM.MachineState{memory: <<>>, active_words: 0}, 5, <<1, 1>>)
      %EVM.MachineState{memory: <<0, 0, 0, 0, 0, 1, 1>>, active_words: 1}

      iex> EVM.Memory.write(%EVM.MachineState{memory: <<0, 1, 2, 3, 4>>, active_words: 0}, 1, <<6, 6>>)
      %EVM.MachineState{memory: <<0, 6, 6, 3, 4>>, active_words: 1}

      iex> EVM.Memory.write(%EVM.MachineState{memory: <<0, 1, 2, 3, 4>>, active_words: 0}, 0, <<10, 11, 12, 13, 14, 15>>)
      %EVM.MachineState{memory: <<10, 11, 12, 13, 14, 15>>, active_words: 1}

      iex> EVM.Memory.write(%EVM.MachineState{memory: <<1, 1, 1>>, active_words: 0}, 5, <<1::80>>)
      %EVM.MachineState{memory: <<1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>, active_words: 1}
  """
  @spec write(MachineState.t, EVM.val, EVM.val) :: MachineState.t
  def write(machine_state, offset_bytes, data) do
    memory_size = byte_size(machine_state.memory)
    data_size = byte_size(data)
    final_pos = offset_bytes + data_size
    padding_bits = ( max(final_pos - memory_size, 0) ) * 8
    final_memory_byte = max(memory_size - final_pos, 0)

    memory = machine_state.memory <> <<0::size(padding_bits)>>

    updated_memory = :binary.part(memory, 0, offset_bytes) <> data <> :binary.part(memory, final_pos, final_memory_byte)

    %{machine_state | memory: updated_memory }
      |> MachineState.maybe_set_active_words(get_active_words(offset_bytes + data_size))
  end

  @doc """
  Read zeroed memory will read bytes from a certain offset in the memory
  binary. Any bytes extending beyond memory's size will be defauled to zero.

  ## Examples

      iex> EVM.Memory.read_zeroed_memory(<<1, 2, 3>>, 1, 4)
      <<2, 3, 0, 0>>

      iex> EVM.Memory.read_zeroed_memory(<<1, 2, 3>>, 1, 2)
      <<2, 3>>

      iex> EVM.Memory.read_zeroed_memory(<<16, 17, 18, 19>>, 100, 1)
      <<0>>
  """
  @spec read_zeroed_memory(binary(), EVM.val, EVM.val) :: binary()
  def read_zeroed_memory(memory, offset, bytes) do
    memory_size = byte_size(memory)

    if offset > memory_size do
      # We're totally out of memory, let's just drop zeros
      bytes_in_bits = bytes * 8
      <<0::size(bytes_in_bits)>>
    else
      final_pos = offset + bytes
      memory_bytes_final_pos = min(final_pos, memory_size)
      padding = ( final_pos - memory_bytes_final_pos ) * 8

      :binary.part(memory, offset, memory_bytes_final_pos - offset) <> <<0::size(padding)>>
    end
  end

  @doc """
  Returns the highest active word from the given inputs.

  ## Examples

      iex> EVM.Memory.get_active_words(0) # TODO: We may actually want this to start at 1, even for zero bytes read
      0

      iex> EVM.Memory.get_active_words(80)
      3

      iex> EVM.Memory.get_active_words(321)
      11
  """
  def get_active_words(bytes) do
    # note: round has no effect due to ceil, just being used for float to int conversion
    :math.ceil( bytes / 32 ) |> round
  end
end