defprotocol Exleveldb.Keys do
  @doc """
  Implicitly converts integer, atom, or list keys
  to strings when passed to either `Exleveldb.put/3` or
  `Exleveldb.get/2` in order to please the binary LevelDB gods.
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

