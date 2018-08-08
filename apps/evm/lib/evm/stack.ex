defmodule EVM.Stack do
  @moduledoc """
  Operations to read / write to the EVM's stack.
  """

  @type t :: [EVM.val()]

  @doc """
  Pushes value onto stack.

  ## Examples

      iex> EVM.Stack.push([], 5)
      [5]

      iex> EVM.Stack.push([5], 6)
      [6, 5]

      iex> EVM.Stack.push([], [5, 6])
      [5, 6]
  """
  @spec push(t, EVM.val() | list(EVM.val())) :: t
  def push(stack, val) when is_list(val), do: val ++ stack
  def push(stack, val), do: [val | stack]

  @doc """
  Pops value from stack, returning a new
  stack with value popped.

  This function raises if stack is empty.

  ## Examples

      iex> EVM.Stack.pop([1, 2, 3])
      {1, [2, 3]}

      iex> EVM.Stack.pop([5])
      {5, []}

      iex> EVM.Stack.pop([])
      ** (FunctionClauseError) no function clause matching in EVM.Stack.pop/1
  """
  @spec pop(t) :: {EVM.val(), t}
  def pop([h | t]), do: {h, t}

  @doc """
  Peeks at head of stack, returns nil
  if stack is empty.

  ## Examples

      iex> EVM.Stack.peek([])
      nil

      iex> EVM.Stack.peek([1, 2])
      1
  """
  @spec peek(t) :: EVM.val() | nil
  def peek([]), do: nil
  def peek([h | _]), do: h

  @doc """
  Peeks at n elements of stack, and
  raises if unsufficient elements exist.

  ## Examples

      iex> EVM.Stack.peek_n([1, 2, 3], 2)
      [1, 2]

      iex> EVM.Stack.peek_n([1, 2, 3], 4)
      [1, 2, 3]
  """
  @spec peek_n(t, integer()) :: [EVM.val()]
  def peek_n(stack, n) do
    {r, _} = pop_n(stack, n)

    r
  end

  @doc """
    Pops multiple values off of stack, returning a new stack
    less that many elements.

    Raises if stack contains insufficient elements.

    ## Examples

        iex> EVM.Stack.pop_n([1, 2, 3], 0)
        {[], [1, 2, 3]}

        iex> EVM.Stack.pop_n([1, 2, 3], 1)
        {[1], [2, 3]}

        iex> EVM.Stack.pop_n([1, 2, 3], 2)
        {[1, 2], [3]}

        iex> EVM.Stack.pop_n([1, 2, 3], 4)
        {[1, 2, 3], []}
  """
  @spec pop_n(t, integer()) :: {[EVM.val()], t}
  def pop_n(stack, 0), do: {[], stack}

  def pop_n([h | t], n) do
    {a, b} = pop_n(t, n - 1)

    {[h | a], b}
  end

  def pop_n([], _stack), do: {[], []}

  @doc """
  Returns the length of the stack.

  ## Examples

      iex> EVM.Stack.length([1, 2, 3])
      3

      iex> EVM.Stack.length([])
      0
  """
  @spec length(t) :: integer()
  def length(stack), do: Kernel.length(stack)

  def replace(stack, n, val), do: List.replace_at(stack, n, val)
end
