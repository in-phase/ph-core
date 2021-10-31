module Phase
  # A `ShapeError` is raised when the shape (see `MultiIndexable#shape`) of a data
  # type is incorrect for a given operation.
  class ShapeError < Exception
    def self.initialize(message : String? = nil)
      super(message || "Shape was invalid for this operation.")
    end
  end

  # A `DimensionError` is raised when the dimensionality of a data type is
  # incorrect for a given operation. For example, a method that will work on any
  # matrix should raise a `DimensionError` when passed a 3D `MultiIndexable` - the
  # shape values should not matter, only the dimension.
  #
  # If you do not care about disambiguating between `ShapeError` and `DimensionError`,
  # note that `DimensionError` is a subclass of `ShapeError` - so you only need
  # to `rescue ex : ShapeError` and you'll catch both kinds.
  class DimensionError < ShapeError
    def self.initialize(message : String? = nil)
      super(message || "Wrong number of dimensions for this operation.")
    end
  end
end
