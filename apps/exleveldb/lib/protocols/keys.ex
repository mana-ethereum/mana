defprotocol Exleveldb.Keys do
  @doc """
  Implicitly converts other to strings when passed in
  as the second argument to `Exleveldb.put/3`
  in order to please the binary LevelDB gods.
  """
  def to_key(name)
end

defimpl Exleveldb.Keys, for: Integer do
  def to_key(number), do: Integer.to_string number
end

defimpl Exleveldb.Keys, for: Atom do
  def to_key(atom), do: Atom.to_string atom
end

defimpl Exleveldb.Keys, for: List do
  def to_key(charlist), do: List.to_string(charlist)
end

