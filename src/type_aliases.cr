module Phase
  # In theory, these types should represent Array(Int); however, these are difficult
  # for the compiler to check as every combination of integer union types
  # must be checked for separately.
  # We instead allow any type parameter, with the expectation that compile errors
  # will be thrown when trying to use the inner type with operations defined
  # only for Ints.

  # Should be used for return types and type restriction. This will always be
  # defined as loosely as possible
  alias Coord = Indexable # deprecated
  alias InputCoord = Indexable # The type of coordinate that a user can provide (basically any container)
  alias OutputCoord = Array # The type of coordinate that phase will output
  alias RegionLiteral = Indexable # The type of a user-provided region literal (e.g [1..2, -3..2..])

  alias Shape = Indexable
end
