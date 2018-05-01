defmodule EVM.Operation.Logging do
  alias EVM.{Operation, Memory, SubState}

  @doc """
  Append log record with no topics.

  ## Examples

      iex> env = %EVM.ExecEnv{
      ...>  account_interface: %EVM.Interface.Mock.MockAccountInterface{},
      ...>  address: 87579061662017136990230301793909925042452127430,
      ...>  block_interface: %EVM.Interface.Mock.MockBlockInterface{}
      ...> }
      iex> machine_state = %EVM.MachineState{
      ...>   active_words: 1,
      ...>   gas: 99351,
      ...>   memory: <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255>>,
      ...>   previously_active_words: 0,
      ...>   program_counter: 40,
      ...>   stack: []
      ...> }
      iex> sub_state = %EVM.SubState{logs: [], refund: 0, suicide_list: []}
      iex> vm_map = %{sub_state: sub_state, exec_env: env, machine_state: machine_state}
      iex> EVM.Operation.Logging.log0([0, 32], vm_map)
      %{
        sub_state: %EVM.SubState{
          logs: [
            %EVM.LogEntry{
              address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47,
                109, 45, 108, 123, 94, 198>>,
              data: <<255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255>>,
              topics: []
            }
          ],
          refund: 0,
          suicide_list: []
        }
      }
  """
  @spec log0(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log0(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with one topic.

  ## Examples

      iex> env = %EVM.ExecEnv{
      ...>   account_interface: %EVM.Interface.Mock.MockAccountInterface{},
      ...>   address: 87579061662017136990230301793909925042452127430,
      ...>   block_interface: %EVM.Interface.Mock.MockBlockInterface{}
      ...> }
      iex> machine_state = %EVM.MachineState{
      ...>   active_words: 1,
      ...>   gas: 99351,
      ...>   memory: <<170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 204, 221>>,
      ...>   previously_active_words: 0,
      ...>   program_counter: 40,
      ...>   stack: []
      ...> }
      iex> sub_state = %EVM.SubState{logs: [], refund: 0, suicide_list: []}
      iex> vm_map = %{sub_state: sub_state, exec_env: env, machine_state: machine_state}
      iex> args = [0, 32, 115792089237316195423570985008687907853269984665640564039457584007913129639935]
      iex> EVM.Operation.Logging.log1(args, vm_map)
      %{
        sub_state: %EVM.SubState{
          logs: [
            %EVM.LogEntry{
              address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47,
                109, 45, 108, 123, 94, 198>>,
              data: <<170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 204, 221>>,
              topics: [115792089237316195423570985008687907853269984665640564039457584007913129639935]
            }
          ],
          refund: 0,
          suicide_list: []
        }
      }
  """
  @spec log1(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log1(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with two topics.

  ## Examples

      iex> env = %EVM.ExecEnv{
      ...>   account_interface: %EVM.Interface.Mock.MockAccountInterface{},
      ...>   address: 87579061662017136990230301793909925042452127430,
      ...>   block_interface: %EVM.Interface.Mock.MockBlockInterface{}
      ...> }
      iex> machine_state = %EVM.MachineState{
      ...>   active_words: 1,
      ...>   gas: 99351,
      ...>   memory: <<170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 204, 221>>,
      ...>   previously_active_words: 0,
      ...>   program_counter: 40,
      ...>   stack: []
      ...> }
      iex> sub_state = %EVM.SubState{logs: [], refund: 0, suicide_list: []}
      iex> vm_map = %{sub_state: sub_state, exec_env: env, machine_state: machine_state}
      iex> args = [0, 32,
      ...>   115792089237316195423570985008687907853269984665640564039457584007913129639935,
      ...>   115792089237316195423570985008687907853269984665640564039457584007913129639935]
      iex> EVM.Operation.Logging.log1(args, vm_map)
      %{
        sub_state: %EVM.SubState{
          logs: [
            %EVM.LogEntry{
              address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47,
                109, 45, 108, 123, 94, 198>>,
              data: <<170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
                255, 255, 255, 204, 221>>,
              topics: [115792089237316195423570985008687907853269984665640564039457584007913129639935,
               115792089237316195423570985008687907853269984665640564039457584007913129639935]
            }
          ],
          refund: 0,
          suicide_list: []
        }
      }
  """
  @spec log2(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log2(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with three topics.

  ## Examples

      iex> env = %EVM.ExecEnv{
      ...>   account_interface: %EVM.Interface.Mock.MockAccountInterface{},
      ...>   address: 87579061662017136990230301793909925042452127430,
      ...>   block_interface: %EVM.Interface.Mock.MockBlockInterface{}
      ...> }
      iex> machine_state = %EVM.MachineState{
      ...>   active_words: 1,
      ...>   gas: 99351,
      ...>   memory:  <<170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 204, 221>>,
      ...>   previously_active_words: 0,
      ...>   program_counter: 40,
      ...>   stack: []
      ...> }
      iex> sub_state = %EVM.SubState{logs: [], refund: 0, suicide_list: []}
      iex> vm_map = %{sub_state: sub_state, exec_env: env, machine_state: machine_state}
      iex> args = [1, 0, 0, 0, 0]
      iex> EVM.Operation.Logging.log1(args, vm_map)
      %{
        sub_state: %EVM.SubState{
          logs: [
            %EVM.LogEntry{
              address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47,
                109, 45, 108, 123, 94, 198>>,
              data: "",
              topics: [0, 0, 0]
            }
          ],
          refund: 0,
          suicide_list: []
        }
      }
  """
  @spec log3(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log3(args, vm_map) do
    args |> log(vm_map)
  end

  @doc """
  Append log record with four topics.

  ## Examples

      iex> env = %EVM.ExecEnv{
      ...>   account_interface: %EVM.Interface.Mock.MockAccountInterface{},
      ...>   address: 87579061662017136990230301793909925042452127430,
      ...>   block_interface: %EVM.Interface.Mock.MockBlockInterface{}
      ...> }
      iex> machine_state = %EVM.MachineState{
      ...>   active_words: 1,
      ...>   gas: 99351,
      ...>   memory: <<127, 170, 187, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 204, 221, 96, 0, 82, 96, 0, 96, 0, 96, 0, 96, 0, 96,
      ...>     1, 127, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
      ...>     255, 255, 255, 255, 164>>,
      ...>   previously_active_words: 0,
      ...>   program_counter: 40,
      ...>   stack: []
      ...> }
      iex> sub_state = %EVM.SubState{logs: [], refund: 0, suicide_list: []}
      iex> vm_map = %{sub_state: sub_state, exec_env: env, machine_state: machine_state}
      iex> args = [115792089237316195423570985008687907853269984665640564039457584007913129639935,
      ...>   1, 0, 0, 0, 0]
      iex> EVM.Operation.Logging.log1(args, vm_map)
      %{
        sub_state: %EVM.SubState{
          logs: [
            %EVM.LogEntry{
              address: <<15, 87, 46, 82, 149, 197, 127, 21, 136, 111, 155, 38, 62, 47,
                109, 45, 108, 123, 94, 198>>,
              data: <<0>>,
              topics: [0, 0, 0, 0]
            }
          ],
          refund: 0,
          suicide_list: []
        }
      }
  """
  @spec log4(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  def log4(args, vm_map) do
    args |> log(vm_map)
  end

  @spec log(Operation.stack_args(), Operation.vm_map()) :: Operation.op_result()
  defp log([offset, size | topics], %{
         exec_env: exec_env,
         sub_state: sub_state,
         machine_state: machine_state
       }) do
    {data, _} = machine_state |> Memory.read(offset, size)
    address = exec_env.address
    updated_substate = sub_state |> SubState.add_log(address, topics, data)

    %{sub_state: updated_substate}
  end
end
