module Lattice

  # A set of methods to manage region specifiers.
  module RegionHelpers
    extend self

    # TODO: define "canonical form" of coord/region/index somewhere visible and easy to access.

    # Checks if `index` is a valid index along `axis` for an array-like object with dimensions specified by `shape`.
    def has_index?(index, shape, axis)
      index >= -shape[axis] && index < shape[axis]
    end

    # Checks if `coord` is a valid coordinate for an array-like object with dimensions specified by `shape`.
    # A coord is a list (Enumerable) of integers specifying an index along each axis in `shape`.
    def has_coord?(coord, shape)
      coord.to_a.map_with_index {|index, axis| has_index?(coord, shape, axis)}.all?
    end

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

    # Returns the canonical (positive) form of `index` along a particular `axis` of `shape`.
    # Throws an `IndexError` if `index` is out of range of `shape` along this axis.
    def canonicalize_index(index, shape, axis)
      if !has_index?(index, shape, axis)
        raise IndexError.new("Could not canonicalize index: #{index} is not a valid index in axis #{axis} of shape #{shape}.")
      end
      canonicalize_index_unsafe(index, shape, axis)
    end

    # Performs a conversion as in `#canonicalize_index`, but does not guarantee the result is actually a canonical index.
    # This may be useful if additional manipulations must be performed on the result before use, but it is strongly advised
    # that the index be validated before or after this method is called.
    protected def canonicalize_index_unsafe(index, shape, axis)
      if index < 0
        return shape[axis] + index
      else
        return index
      end
    end

    # Converts a `coord` into canonical form, such that each index in `coord` is positive.
    # Throws an `IndexError` if at least one index specified in `coord` is out of range for the 
    # corresponding axis of `shape`.
    def canonicalize_coord(coord, shape) : Array(Int32)
      coord.to_a.map_with_index { |index, axis| canonicalize_index(index, shape, axis).to_i32 }
    end


    # Given a range in some dimension (typically the domain to slice in), returns a canonical
    # form where both indexes are positive and the range is strictly inclusive of its bounds.
    # This method also returns a direction parameter, which is 1 iff `begin` < `end` and
    # -1 iff `end` < `begin`
    def canonicalize_range(range, shape, axis) : Tuple(Range(Int32, Int32), Int32)
      positive_begin = canonicalize_index(range.begin || 0, shape, axis)
      # definitely not negative, but we're not accounting for exclusivity yet
      positive_end = canonicalize_index_unsafe(range.end || (shape[axis] - 1), shape, axis)

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
      # (Note: a `#has_index?` check will not suffice here, since it may return true for negative indices.
      if positive_end < 0 || positive_end >= shape[axis]
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
      end

      # TODO: This function is supposed to support both Range and StepIterator - in the latter case, direction != step_size
      # Need to measure step size and properly return it
      {Range.new(positive_begin, positive_end), direction}
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
        case rule
        when Range, SteppedRange
          # Ranges are the only implementation we support
          range, step = canonicalize_range(rule, shape, axis)
          next SteppedRange.new(range, step)
        else
          # This branch is supposed to capture numeric objects. We avoid specifying type
          # explicitly so we can have the most interoperability.
          index = canonicalize_index(rule, shape, axis)
          next SteppedRange.new((index..index), 1)
        end
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
      # TODO discuss: this check should not be necessary since we are assuming the region is canonical?
      # if region.size != @shape.size
      #   raise DimensionError.new("Could not measure canonical range - A region with #{region.size} dimensions cannot be canonical over a #{@shape.size} dimensional {{@type}}.")
      # end

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

    # Stores similar information to a StepIterator, which (as of Crystal 0.36) have issues of uncertain types and may change behaviour in the future.
    # To avoid compatibility issues we define our own struct here.
    struct SteppedRange
      getter size : Int32
      getter range : Range(Int32, Int32)
      getter step : Int32

      def initialize(@range : Range(Int32, Int32), @step : Int32)
        @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
      end

      def initialize(index)
        @size = 1
        @step = 1
        @range = index..index
      end

      # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
      # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
      # going forwards or backwards.
      # TODO: Better docs
      # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (Crystal 0.36)
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

      def inspect(io)
        if @size == 1
          io << @range.begin.to_s
        else
          io << "(#{@range}).step(#{@step})"
        end
      end

      def begin
        @range.begin
      end

      def end
        @range.end
      end

      def excludes_end?
        false
      end
    end
  end
end
