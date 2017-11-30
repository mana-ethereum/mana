defmodule ABI.FunctionSelector do
  @moduledoc """
  Module to help parse the ABI function signatures, e.g.
  `my_function(uint64, string[])`.
  """

  require Integer

  @type type ::
    {:uint, integer()} |
    :bool

  @type t :: %__MODULE__{
    function: String.t,
    types: [type],
    returns: type
  }

  defstruct [:function, :types, :returns]

  @doc """
  Decodes a function selector to struct. This is a simple version
  and we may opt to do format parsing later.

  ## Examples

      iex> ABI.FunctionSelector.decode("bark(uint256,bool)")
      %ABI.FunctionSelector{
        function: "bark",
        types: [
          {:uint, 256},
          :bool
        ]
      }

      iex> ABI.FunctionSelector.decode("growl(uint,address,string[])")
      %ABI.FunctionSelector{
        function: "growl",
        types: [
          {:uint, 256},
          :address,
          {:array, :string}
        ]
      }
  """
  def decode(signature) do
    captures = Regex.named_captures(~r/(?<function>[a-zA-Z_$][a-zA-Z_$0-9]*)\((?<types>(([^,]+),?)+)\)/, signature)

    %ABI.FunctionSelector{
      function: captures["function"],
      types: captures["types"] |> String.split(",") |> Enum.map(&decode_type/1),
      returns: nil
    }
  end

  def decode_type("uint" <> size_str) do
    size = case size_str do
      "" -> 256 # default
      _ ->
        {size, ""} = Integer.parse(size_str)

        size
    end

    {:uint, size}
  end

  def decode_type("bool"), do: :bool
  def decode_type("string"), do: :string
  def decode_type("address"), do: :address
  def decode_type(els) do
    if String.ends_with?(els, "[]") do
      {:array,
        els
        |> String.slice(0, String.length(els) - 2)
        |> decode_type()}
    else
      raise "Unsupported type: #{els}"
    end
  end

  @doc """
  Encodes a function call signature.

  ## Examples

      iex> ABI.FunctionSelector.encode(%ABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string}
      ...>   ]
      ...> })
      "bark(uint256,bool,string[])"
  """
  def encode(function_selector) do
    types = get_types(function_selector) |> Enum.join(",")

    "#{function_selector.function}(#{types})"
  end

  defp get_types(function_selector) do
    for type <- function_selector.types do
      get_type(type)
    end
  end

  defp get_type({:uint, size}), do: "uint#{size}"
  defp get_type(:bool), do: "bool"
  defp get_type(:string), do: "string"
  defp get_type(:address), do: "address"
  defp get_type({:array, type}), do: "#{get_type(type)}[]"
  defp get_type(els), do: "Unsupported type: #{els}"

end
