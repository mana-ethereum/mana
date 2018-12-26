defmodule JSONRPC2.SpecHandler.CallRequest do
  import JSONRPC2.Response.Helpers

  defstruct [
    :from,
    :to,
    :gas,
    :gas_price,
    :value,
    :data
  ]

  @type t :: %__MODULE__{
          from: binary(),
          to: binary(),
          gas: integer(),
          gas_price: integer(),
          value: integer(),
          data: binary()
        }

  @spec new(map()) :: {:ok, t()} | {:error, :invalid_params}
  def new(params) do
    with {:ok, from} <- params |> Map.get("from") |> parse_binary(),
         {:ok, to} <- params |> Map.get("to") |> parse_binary(),
         {:ok, gas} <- params |> Map.get("gas") |> parse_integer(),
         {:ok, gas_price} <- params |> Map.get("gas_price") |> parse_integer(),
         {:ok, value} <- params |> Map.get("value") |> parse_integer(),
         {:ok, data} <- params |> Map.get("data") |> parse_binary() do
      %__MODULE__{
        from: from,
        to: to,
        gas: gas,
        gas_price: gas_price,
        value: value,
        data: data
      }
    end
  end

  @spec parse_integer(binary() | nil) :: {:ok, nil | integer()} | {:error, :invalid_params}
  defp parse_integer(nil), do: {:ok, nil}

  defp parse_integer(binary) do
    decode_unsigned(binary)
  end

  @spec parse_binary(binary() | nil) :: {:ok, nil | integer()} | {:error, :invalid_params}
  defp parse_binary(nil), do: {:ok, nil}

  defp parse_binary(binary) do
    decode_hex(binary)
  end
end
