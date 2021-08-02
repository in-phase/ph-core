module Phase
  module CoordUtil
    extend self

    def has_index?(index, size)
      index >= -size && index < size
    end

    # Checks if `index` is a valid index along `axis` for an array-like object with dimensions specified by `shape`.
    def has_index?(index, shape, axis)
      has_index?(index, shape[axis])
    end

    # Checks if `coord` is a valid coordinate for an array-like object with dimensions specified by `shape`.
    # A coord is a list (Enumerable) of integers specifying an index along each axis in `shape`.
    def has_coord?(coord, shape)
      return false if coord.size != shape.size
      coord.to_a.map_with_index { |index, axis| has_index?(index, shape, axis) }.all?
    end

    # Returns the canonical (positive) form of `index` along a particular `axis` of `shape`.
    # Throws an `IndexError` if `index` is out of range of `shape` along this axis.
    def canonicalize_index(index, shape, axis)
      canonicalize_index(index, shape[axis])
    end

    def canonicalize_index(index, size)
      if !has_index?(index, size)
        raise IndexError.new("Could not canonicalize index: #{index} is not a valid index for an axis of length #{size}.")
      end
      canonicalize_index_unsafe(index, size)
    end

    # Performs a conversion as in `#canonicalize_index`, but does not guarantee the result is actually a canonical index.
    # This may be useful if additional manipulations must be performed on the result before use, but it is strongly advised
    # that the index be validated before or after this method is called.
    protected def canonicalize_index_unsafe(index, size : Int)
      if index < 0
        return index + size
      else
        return index
      end
    end

    # Converts a `coord` into canonical form, such that each index in `coord` is positive.
    # Throws an `IndexError` if at least one index specified in `coord` is out of range for the
    # corresponding axis of `shape`.
    def canonicalize_coord(coord, shape) : Coord
      coord.to_a.map_with_index { |index, axis| canonicalize_index(index, shape, axis).to_i32 }
    end
  end
end
