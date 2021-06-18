module Lattice
  # For a given axis length `size`, a "canonical range" `range` obeys the following:
  # - Stored as a `SteppedRange` object
  # - `range.begin` and `range.end` are canonical indices for an axis of length `size`
  # - `range.size >= 0` and represents the number of elements that would be iterated through
  # - `range.begin + (range.size * range.step) == range.end`. In particular this means:
  #    -
  # - If empty (no elements spanned), then all of `range.size, range.step, range.begin, range.end` are 0.

  # Stores similar information to a StepIterator, which (as of Crystal 0.36) have issues of uncertain types and may change behaviour in the future.
  # To avoid compatibility issues we define our own struct here.
  struct SteppedRange(T)
    getter size : T
    getter step : T
    getter begin : T
    getter end : T

    def self.empty
      SteppedRange.new
    end

    def self.new(range : Range, step, bound)
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
      SteppedRange.new(CoordUtil.canonicalize_index(index, bound))
    end

    protected def initialize(@begin : T, @end : T, @step : T)
      @size = ((@end - @begin) // @step).abs + 1
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

    protected def self.canonicalize(start : T?, stop : T?, exclusive : Bool, bound : T, step : T? = nil) : SteppedRange(T) forall T
      if !step
        # Infer endpoints normally, and determine iteration direction
        start = start ? CoordUtil.canonicalize_index(start, bound) : 0
        if stop
          temp_stop = CoordUtil.canonicalize_index_unsafe(stop, bound)
          step = (temp_stop - start >= 0) ? 1 : -1
        else
          temp_stop = bound - 1
          # what if T == UInt8?
          # then step will be upcasted to Int32 i think (wait this might not be true)
          # oh weird
          # that might be ok though?
          # what's important is that start and stop are T
          # because the iterators and stuff just start there and add steps
          # true true
          step = T.zero + 1 # if this doesn't work... call 911
        end
      else
        # Infer endpoints by step direction; and confirm step is compatible with existing endpoints
        start = start ? CoordUtil.canonicalize_index(start, bound) : (step > 0 ? 0 : bound - 1)
        temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : (step > 0 ? bound - 1 : 0)
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
      else
        if @step.abs == 1
          io << "#{@begin..@end}"
        else
          io << "#{@begin}..#{@step}..#{@end}"
        end
      end
    end
  end
end
