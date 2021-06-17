module Lattice
  module RegionUtil
    # alias RangeSpecifier = Int32 | Range(Int32?, Int32? | Range(Int32?, Int32))

    # For a given axis length `size`, a "canonical index" `idx` is `0 <= idx < size`.

    # Checks if `region` is a valid region specifier for an array-like object with dimensions specified by `shape`.
    # A region specifier (RS) is a list of integers and ranges specifying an index, or set of indices, along
    # each axis in `shape`.
    def has_region?(region, shape)
      begin
        canonicalize_region(region, shape)
      rescue exception
        return false
      end
      true
    end

    def canonicalize_range(range, shape, axis) : SteppedRange
      SteppedRange.new(range, shape[axis])
    end

    # TODO: specify parameters, implement step sizes other than 1
    # Converts a region specifier to a legal, canonical region specifier.
    # If the input region is not a valid subregion of the given shape, an error will be thrown.
    # Returns a list of `SteppedRange`s in canonical form - i.e, it satisfies:
    #   - the size of the list is equal to the size of `shape`
    #   - For each `steppedRange`:
    #     - `step != 0`
    #     - `range.begin` and `range.end` are explicitly integers representing valid indices for the
    #           corresponding axis of `shape`, in canonical (positive) form
    #     - if `step > 0`, then `range.begin <= range.end`, and if `step < 0`, then `range.begin <= range.end`
    #     - `range` is inclusive
    def canonicalize_region(region, shape) : Array(SteppedRange)
      canonical_region = region.to_a + [..] * (shape.size - region.size)
      canonical_region = canonical_region.map_with_index do |rule, axis|
        next canonicalize_range(rule, shape, axis)
      end
    end

    # Returns the `shape` of a region when sampled from this `{{@type}}`.
    # For example, on a 5x5x5 {{@type}}, `measure_shape(1..3, ..., 5)` => `[3, 5]`.
    def measure_region(region, shape) : Array(Int32)
      measure_canonical_region(canonicalize_region(region, shape))
    end

    # See `#measure_region`. The only difference is that this method assumes
    # the region is already canonicalized, which can provide speedups.
    # TODO: account for step sizes
    def measure_canonical_region(region) : Array(Int32)
      shape = [] of Int32

      # Measure the effect of applied restrictions (if a rule is a number, a dimension
      # gets dropped. If a rule is a range, a dimension gets resized)
      region.each do |range|
        shape << range.size
      end

      return [1] if shape.empty?
      return shape
    end

    # checks if two shapes define the same data layout, i.e. are equal up to trailing ones.
    def compatible_shapes(shape1, shape2)
      if shape1.size > shape2.size
        larger = shape1
        shared_dims = shape2.size
      else
        larger = shape2
        shared_dims = shape1.size
      end

      # Check that sizes match along shared dimensions
      shared_dims.times do |i|
        return false if shape1[i] != shape2[i]
      end
      # Check that any extra dimensions are 1
      (shared_dims...larger.size).step(1) do |i|
        return false if larger[i] != 1
      end
      true
    end

    def full_region(shape) : Array(SteppedRange)
      shape.map do |dim|
        SteppedRange.new(0, dim - 1, 1)
      end
    end

    def translate_shape(region_shape, coord, parent_shape) : Array(SteppedRange)
      top_left = canonicalize_coord(coord, parent_shape)
      top_left.map_with_index do |start, i|
        SteppedRange.new_canonical(start, start + region_shape[i] - 1, 1)
      end
    end

    def trim_region(region, shape)
      region.map_with_index do |range, i|
        SteppedRange.new(range, Int32::MAX).trim(shape[i])
      end
    end
  end
end
