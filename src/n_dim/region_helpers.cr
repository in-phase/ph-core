module Lattice
  # A set of methods to manage region specifiers.
  module RegionHelpers
    extend self

    # al_ias RangeSpecifier = Int32 | Range(Int32?, Int32? | Range(Int32?, Int32))

    # TODO: define "canonical form" of coord/region/index somewhere visible and easy to access.

    # For a given axis length `size`, a "canonical index" `idx` is `0 <= idx < size`.
    # For a given axis length `size`, a "canonical range" `range` obeys the following:
    # - Stored as a `SteppedRange` object
    # - `range.begin` and `range.end` are canonical indices for an axis of length `size`
    # - `range.size >= 0` and represents the number of elements that would be iterated through
    # - `range.begin + (range.size * range.step) == range.end`. In particular this means:
    #    - 
    # - If empty (no elements spanned), then all of `range.size, range.step, range.begin, range.end` are 0.
   
    # For a given shape, a "canonical region"
    # - 

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
    protected def canonicalize_index_unsafe(index, size : Int32)
      if index < 0
        return size + index
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
        SteppedRange.new(0,dim - 1,1)
      end
    end

    def region_from_coord(coord) : Array(SteppedRange)
      coord.map do |idx|
        SteppedRange.new(idx)
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

    # Stores similar information to a StepIterator, which (as of Crystal 0.36) have issues of uncertain types and may change behaviour in the future.
    # To avoid compatibility issues we define our own struct here.
    struct SteppedRange
      getter size : Int32
      getter step : Int32
      getter begin : Int32
      getter end : Int32

      def self.empty
        SteppedRange.new
      end

      def self.new(range : Range, step : Int, bound : Int)
        canonicalize(range.begin, range.end, range.excludes_end?, bound, step)
      end

      def self.new(range : SteppedRange, bound)
        canonicalize(range.begin, range.end, false, bound, range.step)
      end
  
      def self.new(range : Range, bound)
        first = range.begin
        case first
        when Range
          # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
          return canonicalize(first.begin, range.end, range.excludes_end?, bound, first.end)
        else
          return canonicalize(first, range.end, range.excludes_end?, bound)
        end
      end

      def self.new_canonical(start, stop, step)
        self.new(start, stop, step)
      end
  
      # This method is supposed to capture numeric objects. We avoid specifying type
      # explicitly so we can have the most interoperability.
      def self.new(index : Int, bound)
        SteppedRange.new(RegionHelpers.canonicalize_index(index, bound))
      end

      protected def initialize(@begin, @end, @step)
        @size = ((@end - @begin) // @step).abs.to_i32 + 1
      end

      protected def initialize
        @size = 0
        @step = 0
        @begin = 0
        @end = 0
      end

      protected def initialize(index)
        @size = 1
        @step = 1
        @begin = index  
        @end = index
      end

      def empty? : Bool
        @size == 0
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

      def trim(new_bound) : SteppedRange
        if @begin >= new_bound
          if @end >= new_bound # both out of bounds
            return SteppedRange.empty
          elsif @step < 0 # We started too high, but terminate inside the bounds
            span = (new_bound - 1) - @end
            span -= span % @step.abs
            return SteppedRange.new(@end + span, @end, @step)
          end
        elsif @step > 0 && @end >= new_bound # start in bounds, increase past bound
          span = (new_bound - 1) - @begin
          span -= span % @step.abs
          return SteppedRange.new(@begin, @begin + span, @step)
        end
        self
      end

      protected def self.canonicalize(start, stop, exclusive, bound, step = nil) : SteppedRange
        if !step
          # Infer endpoints normally, and determine iteration direction
          start = start ? RegionHelpers.canonicalize_index(start, bound) : 0
          if stop
            temp_stop = RegionHelpers.canonicalize_index_unsafe(stop, bound)
            step = (temp_stop - start >= 0) ? 1 : -1
          else
            temp_stop = bound - 1
            step = 1
          end
        else
          # Infer endpoints by step direction; and confirm step is compatible with existing endpoints
          start = start ? RegionHelpers.canonicalize_index(start, bound) : (step > 0 ? 0 : bound - 1)
          temp_stop = stop ? RegionHelpers.canonicalize_index_unsafe(stop, bound) : (step > 0 ? bound - 1 : 0)
          if temp_stop - start != 0 && (temp_stop - start).sign != step.sign
            raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(start, stop, exclusive)} and provided step #{step}")
          end
        end



        # Account for exclusive ends of a range
        if stop && exclusive
          if temp_stop == start
            raise IndexError.new("Could not canonicalize range: #{Range.new(start, stop, exclusive)} does not span any integers.")
          end
          temp_stop -= step.sign
        end

        # Account for ranges that do not evenly divide the step (e.g: 1..4 with step 2 will become 1..3 with step 2)
        temp_stop -= (temp_stop - start) % step

        # check temp_stop to ensure it is now a valid index
        if temp_stop < 0 || temp_stop >= bound
          raise IndexError.new("Could not canonicalize range: #{Range.new(start, stop, exclusive)} is not a sensible index range for axis of length #{bound}.")
        end
        SteppedRange.new(start, temp_stop, step)
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