module Lattice
  abstract class AbstractNArray(T)
    # Returns an array where `shape[i]` is the size of the NArray in the `i`th dimension.
    abstract def shape : Array(Int32)

    # Maps a zero-dimensional NArray to the element it contains.
    abstract def to_scalar : T

    # Takes a single index into the NArray, returning a slice of the largest dimension possible.
    # For example, if `a` is a matrix, `a[0]` will be a vector.
    abstract def [](index) : AbstractNArray(T)

    # Higher-order slicing operations (like slicing in numpy)
    abstract def [](*coord) : AbstractNArray(T)

    # Given a fully-qualified coordinate, returns the scalar at that position.
    abstract def get(*coord) : T

    # Returns a deep copy of the array.
    abstract def clone : AbstractNArray(T)

    # Returns a shallow copy of the array.
    abstract def dup : AbstractNArray(T)
  end
end
