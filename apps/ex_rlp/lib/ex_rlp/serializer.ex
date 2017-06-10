defmodule ExRLP.Serializer do
  def serialize(object) when is_integer(object) and object == 0 do
    ""
  end

  def serialize(object) when is_integer(object) and object > 0 do
    object |> :binary.encode_unsigned
  end
end
