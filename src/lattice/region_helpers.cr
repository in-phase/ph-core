module Lattice
  module RegionHelpers
    def self.has_coord?(coord, shape)
    end

    # TODO: Rename and document
    def self.has_region?(coord, shape)
      begin
        canonicalize_region(coord, shape)
      rescue exception
        return false
      end
      true
    end

    # TODO combine/revise docs
    # Converts a region specifier to canonical form.
    # A canonical region specifier obeys the following:
    # - No implicit trailing ranges; the dimensions of the RS matches that of the {{@type}}.
    #     Eg, for a 3x3x3, [.., 2] is non-canonical
    # - All elements are ranges (single-number indexes must be converted to ranges of a single element)
    # - Both the start and end of the range must be positive, and in range for the axis in question
    # - The ranges must be inclusive (eg, 1..2, not 1...3)
    # - In each range, start < end indicates forward direction; start > end indicates backward

    # Applies `#canonicalize_index` and `#canonicalize_range` to each element of a region specification.
    # In order to fully canonicalize the region, it will also add wildcard selectors if the region
    # has implicit wildcards (if `region.size < shape.size`).
    #
    # Returns a tuple containing (in this order):
    # - The input region in canonicalized form
    # - An array of equal size to the region that indicates if that index is a scalar (0),
    #     a range with increasing index (+1), or a range with decreasing index (-1).
    def self.canonicalize_region(region, shape) : Array(SteppedRange)
      canonical_region = region.clone.to_a + [..] * (shape.size - region.size)

      canonical_region = canonical_region.map_with_index do |rule, axis|
        case rule
        # TODO: Handle StepIterator or whatever
        when Range
          # Ranges are the only implementation we support
          range, step = canonicalize_range(rule, axis)
          next SteppedRange.new(range, step)
        else
          # This branch is supposed to capture numeric objects. We avoid specifying type
          # explicitly so we can have the most interoperability.
          index = canonicalize_index(rule, axis)
          next SteppedRange.new((index..index), 1)
        end
      end
    end

    def self.canonicalize_coord(coord, shape) : Array[Int32]
      coord.map { |i| canonicalize_index(i, shape) }
    end

    # Returns the `shape` of a region when sampled from this `{{@type}}`.
    # For example, on a 5x5x5 {{@type}}, `measure_shape(1..3, ..., 5)` => `[3, 5]`.
    def measure_region(region) : Array(Int32)
      measure_canonical_region(self.canonicalize_region(region, @shape))
    end

    def each_in_region(region, &block : T, Int32, Int32 ->)
      region = self.canonicalize_region(region, @shape)
      shape = measure_canonical_region(region)

      each_in_canonical_region(region, compute_buffer_step_sizes, &block)
    end

    # TODO docs
    def canonicalize_index_unchecked(index, axis)
      if index < 0
        return @shape[axis] + index
      else
        return index
      end
    end

    # Given a range in some dimension (typically the domain to slice in), returns a canonical
    # form where both indexes are positive and the range is strictly inclusive of its bounds.
    # This method also returns a direction parameter, which is 1 iff `begin` < `end` and
    # -1 iff `end` < `begin`
    def canonicalize_range(range, axis) : Tuple(Range(Int32, Int32), Int32)
      positive_begin = canonicalize_index(range.begin || 0, axis)
      # definitely not negative, but we're not accounting for exclusivity yet
      positive_end = canonicalize_index_unchecked(range.end || (@shape[axis] - 1), axis)

      # The case (positive_end - positive_begin) == 0 will raise an exception below, if the range excludes its end.
      # Otherwise, we may treat it as an "ascending" array of a single element.
      direction = positive_end - positive_begin >= 0 ? 1 : -1

      if range.excludes_end? && range.end
        if positive_begin == positive_end
          raise IndexError.new("Could not canonicalize range: #{range} does not span any integers.")
        end
        # Convert range to inclusive, by adding or subtracting one to the end depending
        # on whether it is ascending or descending
        positive_end -= direction
      end

      # Since the validity of the end value has not been verified yet, do so here:
      if positive_end < 0 || positive_end >= @shape[axis]
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
      end

      # TODO: This function is supposed to support both Range and StepIterator - in the latter case, direction != step_size
      # Need to measure step size and properly return it
      {Range.new(positive_begin, positive_end), direction}
    end

    # See `{{@type}}#measure_region`. The only difference is that this method assumes
    # the region is already canonicalized, which can provide speedups.
    # TODO: account for step sizes
    protected def measure_canonical_region(region) : Array(Int32)
      shape = [] of Int32
      if region.size != @shape.size
        raise DimensionError.new("Could not measure canonical range - A region with #{region.size} dimensions cannot be canonical over a #{@shape.size} dimensional {{@type}}.")
      end

      # Measure the effect of applied restrictions (if a rule is a number, a dimension
      # gets dropped. If a rule is a range, a dimension gets resized)
      region.each do |range|
        if range.size > 1
          shape << range.size
        end
      end

      return [1] if shape.empty?
      return shape
    end

    struct SteppedRange
      getter size : Int32
      getter range : Range(Int32, Int32)
      getter step : Int32

      def initialize(@range : Range(Int32, Int32), @step : Int32)
        @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
      end

      # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
      # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
      # going forwards or backwards.
      # TODO: Better docs
      # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (0.36)
      def each(&block)
        idx = @range.begin
        if @step > 0
          while idx <= @range.end
            yield idx
            idx += @step
          end
        else
          while idx >= @range.end
            yield idx
            idx += @step
          end
        end
        #   @range.step(@step) do |i|
        #     yield i
        #   end
      end

      def begin
        @range.begin
      end

      def end
        @range.end
      end
    end
  end
end
