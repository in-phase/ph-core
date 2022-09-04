module Phase
  # A collection of utility functions for putting coordinates (whose ordinates
  # may be positive, forward indexes, or negative, reverse indexes) into
  # canoncial form.
  module CoordUtil
    extend self

    # :ditto:
    def has_index?(index, size : Int::Unsigned)
      # TODO
      # In the case that `size` is an unsigned int, we cast it to a bigint in
      # order to make sure we don't overflow the axis. But this is slow and could
      # probably be replaced with a macro to ensure that we just cast to the smallest
      # native container
      index < size && index >= -(size.to_big_i)
    end

    # Returns true if a given `index` can be used to access an array axis with `size` elements.
    def has_index?(index, size : Int)
      index < size && index >= -size
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

    # Returns the canonical (positive) form of `index` along a particular axis of a given `size` (number of elements).
    # Throws an `IndexError` if `index` is not a valid positive or negative array index for `size` elements.
    def canonicalize_index(index, size)
      if !has_index?(index, size)
        raise IndexError.new("Could not canonicalize index: #{index} is not a valid index for an axis of length #{size}.")
      end
      canonicalize_index_unsafe(index, size)
    end


    # Performs a conversion as in `#canonicalize_index`, but does not guarantee the result is actually a canonical index.
    # This may be useful if additional manipulations must be performed on the result before use, but it is strongly advised
    # that the index be validated before or after this method is called.
    protected def canonicalize_index_unsafe(index, size : Int::Unsigned)
      if index < 0
        return size.to_big_i + index
      else
        return index
      end
    end

    # See above. This version performs a small memory and time save if size is known to be signed,
    # but will throw an overflow error if size + index is too big/small (note this can only happen 
    # if index is out of bounds for size by more than 1).
    protected def canonicalize_index_unsafe(index, size : Int)
      if index < 0
        return size + index
      else
        index
      end
    end

    # Converts a `coord` into canonical form, such that each index in `coord` is positive.
    # Throws an `IndexError` if at least one index specified in `coord` is out of range for the
    # corresponding axis of `shape`.
    def canonicalize_coord(coord, shape) : Coord
      if coord.size != shape.size
        raise DimensionError.new("Could not canonicalize coordinate #{coord} to fit in shape #{shape}: shape has #{shape.size} dimensions, while coord has #{coord.size}.")
      end

      coord.to_a.map_with_index { |index, axis| canonicalize_index(index, shape, axis).to_i32 }
    end
  end
end
