defprotocol Exleveldb.Values do
  @doc "Implicitly converts integer, atom, or list keys to strings."
  def to_value(non_string)
end

defimpl Exleveldb.Values, for: Integer do
  def to_value(number), do: Integer.to_string number
end

defimpl Exleveldb.Values, for: Atom do
  def to_value(atom), do: Atom.to_string atom
end

defimpl Exleveldb.Values, for: List do
  def to_value(charlist), do: List.to_string(charlist)
end

defimpl Exleveldb.Values, for: BitString do
  def to_value(string), do: string
end
