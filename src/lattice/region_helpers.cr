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
      coord.to_a.map_with_index { |index, axis| has_index?(coord, shape, axis) }.all?
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
      canonicalize_index_unsafe(index, shape[axis])
    end

    # Performs a conversion as in `#canonicalize_index`, but does not guarantee the result is actually a canonical index.
    # This may be useful if additional manipulations must be performed on the result before use, but it is strongly advised
    # that the index be validated before or after this method is called.
    protected def canonicalize_index_unsafe(index, limit : Int32)
      if index < 0
        return limit + index
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
        if range.size > 1
          shape << range.size
        end
      end

      return [1] if shape.empty?
      return shape
    end



    def canonicalize_range(range : SteppedRange, shape, axis)
      canonicalize_range(range.begin, range.end, false, shape, axis, range.step)
    end

    def canonicalize_range(range : Range, shape, axis)
      first = range.begin
      case first
      when Range
        # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
        return canonicalize_range(first.begin, range.end, range.excludes_end?, shape, axis, first.end)
      else
        return canonicalize_range(first, range.end, range.excludes_end?, shape, axis)
      end
    end

    # This method is supposed to capture numeric objects. We avoid specifying type
    # explicitly so we can have the most interoperability.
    def canonicalize_range(index : Int, shape, axis)
      SteppedRange.new(canonicalize_index(index, shape, axis))
    end
    
    # Given a range in some dimension (typically the domain to slice in), returns a canonical
    # form where both indexes are positive and the range is strictly inclusive of its bounds.
    # This method also returns a direction parameter, which is 1 iff `begin` < `end` and
    # -1 iff `end` < `begin`
    protected def canonicalize_range(start, finish, exclusive, shape, axis, step = nil) : SteppedRange
      limit = shape[axis]
      start = start ? canonicalize_index(start, shape, axis) : 0

      if finish
        temp_finish = canonicalize_index_unsafe(finish, limit)
        direction = temp_finish - start >= 0 ? 1 : -1

        # If the original range excludes the end, modify the end to be inclusive, based on iteration direction
        if exclusive
          if temp_finish == start
            raise IndexError.new("Could not canonicalize range: #{Range.new(start, finish, exclusive)} does not span any integers.")
          end
          temp_finish -= direction
          if temp_finish < 0 || temp_finish >= limit
            raise IndexError.new("Could not canonicalize range: #{Range.new(start, finish, exclusive)} is not a sensible index range in axis #{axis} of shape #{shape}.")
          end
        end
      else
        # Implict end
        temp_finish = limit - 1
        direction = 1
      end

      if step
        if step.sign != direction
          raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(start, finish, exclusive)} and provided step #{step}")
        end
        # Account for ranges that do not evenly divide the step (e.g: 1..4 with step 2 will become 1..3 with step 2)
        temp_finish -= (temp_finish - start) % step
      else
        step = direction
      end
      SteppedRange.new(start, temp_finish, step)
    end

    def full_region(shape) : Array(SteppedRange)
      shape.map do |dim|
        SteppedRange.new(0,dim - 1,1)
      end
    end

    # Stores similar information to a StepIterator, which (as of Crystal 0.36) have issues of uncertain types and may change behaviour in the future.
    # To avoid compatibility issues we define our own struct here.
    struct SteppedRange

      getter size : Int32
      getter step : Int32
      getter begin : Int32
      getter end : Int32

      def initialize(@begin, @end, @step)
        @size = ((@end - @begin) // @step).abs.to_i32 + 1
      end

      def self.new(range : Range(Int32, Int32), step : Int32)
        self.new(range.begin, range.end, step)
      end

      def initialize(index)
        @size = 1
        @step = 1
        @begin = index  
        @end = index
      end

      def reverse : SteppedRange
         SteppedRange.new(@end, @begin, -@step)
      end

      # TODO: rename
      # Given an index in the frame of this range, get the absolute index.
      # e.g.: `SteppedRange.new( 1..10, 3 ).translate(1) #=> 4`
      # since counting by 3 from 1, the 2nd entry (index 1) is 4.
      # NOTE: this method assumes `index < @size`.
      def local_to_absolute(index) : Int32
        @begin + index * @step
      end

      # Like translate, but given a range of indices in the frame of this range,
      # return the range of absolute indices.
      # e.g.: `SteppedRange.new( 1..10, 3 ).subrange( SteppedRange.new( 1..3, 2) )`
      # will give `4..6..10`, i.e. a range of the first and third elements of the former range.
      # NOTE: this method assumes subrange may be contained in range, i.e.
      # `subrange.begin < @size` and `subrange.end < @size`
      def compose(subrange : SteppedRange) : SteppedRange
        SteppedRange.new(local_to_absolute(subrange.begin), local_to_absolute(subrange.end), @step * subrange.step)
      end

      # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
      # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
      # going forwards or backwards.
      # TODO: Better docs
      # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (Crystal 0.36)
      def each(&block)
        idx = @begin
        if @step > 0
          while idx <= @end
            yield idx
            idx += @step
          end
        else
          while idx >= @end
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
          io << @begin.to_s
        else if @step.abs == 1
          io << "#{@begin..@end}"
        else
          io << "#{@begin}..#{@step}..#{@end}"
        end
      end

    end
    end
  end
end