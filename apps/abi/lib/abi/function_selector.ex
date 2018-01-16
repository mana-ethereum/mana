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

      iex> ABI.FunctionSelector.decode("rollover()")
      %ABI.FunctionSelector{
        function: "rollover",
        types: []
      }

      iex> ABI.FunctionSelector.decode("pet(address[])")
      %ABI.FunctionSelector{
        function: "pet",
        types: [
          {:array, :address}
        ]
      }

      iex> ABI.FunctionSelector.decode("paw(string[2])")
      %ABI.FunctionSelector{
        function: "paw",
        types: [
          {:array, :string, 2}
        ]
      }

      iex> ABI.FunctionSelector.decode("scram(uint256[])")
      %ABI.FunctionSelector{
        function: "scram",
        types: [
          {:array, {:uint, 256}}
        ]
      }

      iex> ABI.FunctionSelector.decode("shake((string))")
      %ABI.FunctionSelector{
        function: "shake",
        types: [
          {:tuple, [:string]}
        ]
      }
  """
  def decode(signature) do
    captures = Regex.named_captures(~r/(?<function>[a-zA-Z_$][a-zA-Z_$0-9]*)?\((?<types>(([^,]+),?)*)\)/, signature)

    if captures["function"] != "" do
      # Encode as a function call
      %ABI.FunctionSelector{
        function: captures["function"],
        types: decode_raw(captures["types"]),
        returns: nil
      }
    else
      # Encode as a tuple
      %ABI.FunctionSelector{
        function: nil,
        types: [{:tuple, decode_raw(captures["types"])}],
        returns: nil
      }
    end
  end

  @doc """
  Decodes the given type-string as a simple array of types.

  ## Examples

      iex> ABI.FunctionSelector.decode_raw("string,uint256")
      [:string, {:uint, 256}]
  """
  def decode_raw(type_string) do
    type_string
    |> String.split(",", trim: true)
    |> Enum.map(&decode_type/1)
  end

  @doc false
  def parse_specification_item(%{"type" => "function"} = item) do
    %{
      "name" => function_name,
      "inputs" => named_inputs,
      "outputs" => named_outputs
    } = item

    input_types = Enum.map(named_inputs, &parse_specification_type/1)
    output_types = Enum.map(named_outputs, &parse_specification_type/1)

    %ABI.FunctionSelector{
      function: function_name,
      types: input_types,
      returns: List.first(output_types)
    }
  end
  def parse_specification_item(%{"type" => "fallback"}) do
    %ABI.FunctionSelector{
      function: nil,
      types: [],
      returns: nil
    }
  end
  def parse_specification_item(_), do: nil

  defp parse_specification_type(%{"type" => type}), do: decode_type(type)

  @doc false
  def decode_type(full_type) do
    cond do
      # Check for array type
      captures = Regex.named_captures(~r/(?<type>[a-z0-9]+)\[(?<element_count>\d*)\]/, full_type) ->
        type = decode_type(captures["type"])

        if captures["element_count"] != "" do
          {element_count, ""} = Integer.parse(captures["element_count"])

          {:array, type, element_count}
        else
          {:array, type}
        end
      # Check for tuples
      captures = Regex.named_captures(~r/\((?<types>[a-z0-9\[\]]+,?)+\)/, full_type) ->
        types =
          String.split(captures["types"], ",", trim: true)
          |> Enum.map(fn type -> decode_type(type) end)

        {:tuple, types}
      true ->
        decode_single_type(full_type)
    end
  end

  @doc false
  def decode_single_type("uint" <> size_str) do
    size = case size_str do
      "" -> 256 # default
      _ ->
        {size, ""} = Integer.parse(size_str)

        size
    end

    {:uint, size}
  end

  def decode_single_type("bool"), do: :bool
  def decode_single_type("string"), do: :string
  def decode_single_type("address"), do: :address
  def decode_single_type(els) do
    raise "Unsupported type: #{els}"
  end

  @doc """
  Encodes a function call signature.

  ## Examples

      iex> ABI.FunctionSelector.encode(%ABI.FunctionSelector{
      ...>   function: "bark",
      ...>   types: [
      ...>     {:uint, 256},
      ...>     :bool,
      ...>     {:array, :string},
      ...>     {:array, :string, 3},
      ...>     {:tuple, [{:uint, 256}, :bool]}
      ...>   ]
      ...> })
      "bark(uint256,bool,string[],string[3],(uint256,bool))"
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
  defp get_type({:array, type, element_count}), do: "#{get_type(type)}[#{element_count}]"
  defp get_type({:tuple, types}) do
    encoded_types = types
    |> Enum.map(&get_type/1)
    |> Enum.join(",")

    "(#{encoded_types})"
  end
  defp get_type(els), do: "Unsupported type: #{inspect els}"

  @doc false
  @spec is_dynamic?(ABI.FunctionSelector.type) :: boolean
  def is_dynamic?(:bytes), do: true
  def is_dynamic?(:string), do: true
  def is_dynamic?({:array, _type}), do: true
  def is_dynamic?({:array, _type, _length}), do: true
  def is_dynamic?({:tuple, _types}), do: true
  def is_dynamic?(_), do: false

end
