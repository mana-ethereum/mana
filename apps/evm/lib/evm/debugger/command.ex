defmodule EVM.Debugger.Command do
  @moduledoc """
  Defines a command that can be run in the debugger.
  """

  @type t :: %__MODULE__{
          command: atom(),
          name: String.t(),
          shortcut: String.t(),
          description: String.t()
        }

  defstruct command: nil,
            name: nil,
            shortcut: nil,
            description: nil
end
