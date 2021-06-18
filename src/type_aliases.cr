module Lattice
  # In theory, these types should represent Array(Int); however, these are difficult
  # for the compiler to check as every combination of integer union types
  # must be checked for separately.
  # We instead allow any type parameter, with the expectation that compile errors
  # will be thrown when trying to use the inner type with operations defined
  # only for Ints.

  # Should be used for return types and type restriction. This will always be
  # defined as loosely as possible
  alias Coord = Indexable

  alias Shape = Indexable

  # Should only be used as a return type or to restrict the parameters of
  # functions intended to take very limited inputs (e.g. functions in abstract
  # classes where the user shouldn't have to do cleanup)
  alias CanonicalRegion = Indexable(SteppedRange)
end
