defmodule EVM.Operation.Arithmetic do
  defmacro __using__(_params) do
    alias EVM.Helpers
    alias MathHelper

    quote do
      @doc """
      Addition operation.

      Takes an instruction, stack arguments and the current
      state, and returns an updated state.

      The function expects the arguments for the instruction have already
      been popped off the stack.

      ## Examples

          iex> EVM.Operation.Impl.add([1, 2], %{})
          3

          iex> EVM.Operation.Impl.add([-1, -5], %{})
          EVM.Operation.Impl.encode_signed(-6)

          iex> EVM.Operation.Impl.add([0, 0], %{})
          0

          iex> EVM.Operation.Impl.add([EVM.max_int() - 1 - 2, 1], %{})
          EVM.max_int() - 1 - 1

          iex> EVM.Operation.Impl.add([EVM.max_int() - 1 - 2, 5], %{})
          2

          iex> EVM.Operation.Impl.add([EVM.max_int() - 1 + 2, EVM.max_int() - 1 + 2], %{})
          2

          iex> EVM.Operation.Impl.add([EVM.max_int() - 1, 1], %{})
          0
      """
      @spec add(stack_args, vm_map) :: op_result
      def add([s0, s1], _) do
        s0 + s1
          |> Helpers.wrap_int
          |> Helpers.encode_signed
      end
    end
  end
end
