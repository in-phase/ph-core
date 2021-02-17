require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"
require "./n_array.cr"

module Lattice
  class NArray(T) < AbstractNArray(T)
    # Given a range in some dimension (typically the domain to slice in), returns a canonical
    # form where both indexes are positive, and the range is strictly inclusive of its bounds.
    # This method also returns a parameter that encodes the step size of the range.
    # For example: canonicalize_range(5..0, axis) # => {(5..0), -1}
    def canonicalize_range(range, axis) : Tuple(Range(Int32, Int32), Int32)
      positive_begin = canonicalize_index(range.begin || 0, axis)
      # definitely not negative, but we're not accounting for exclusivity yet
      positive_end = canonicalize_index(range.end || (@shape[axis] - 1), axis)

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

      # It's possible to engineer a range with bounds that are meaningless but would break code
      # later on. Detect and raise an exception in that case
      if {positive_begin, positive_end}.any? { |idx| idx < 0 || idx >= @shape[axis] }
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
      end

      # TODO: This function is supposed to support both Range and StepIterator - in the latter case, direction != step_size
      # Need to measure step size and properly return it
      {Range.new(positive_begin, positive_end), direction}
    end

    # Applies `#canonicalize_index` and `#canonicalize_range` to each element of a region specification.
    # In order to fully canonicalize the region, it will also add wildcard selectors if the region
    # has implicit wildcards (if `region.size < shape.size`).
    #
    # Returns a tuple containing (in this order):
    # - The input region in canonicalized form
    # - An array of equal size to the region that indicates if that index is a scalar (0),
    #     a range with increasing index (+1), or a range with decreasing index (-1).
    def canonicalize_region(region) : Array(SteppedRange)
      canonical_region = region.clone + [..] * (@shape.size - region.size)

      canonical_region.map_with_index do |rule, axis|
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
      
    struct SteppedRange
      getter size : Int32

      def initialize(@range : Range(Int32, Int32), @step : Int32)
        @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
      end

      def each(&block)
        @range.step(@step) do |i|
          yield i
        end
      end

      def begin
        @range.begin
      end

      def end
        @range.end
      end
    end

    # See `NArray#measure_region`. The only difference is that this method assumes
    # the region is already canonicalized, which can provide speedups.
    # TODO: account for step sizes
    protected def measure_canonical_region(region) : Array(Int32)
      shape = [] of Int32

      if region.size != @shape.size
        raise DimensionError.new("Could not measure canonical range - A region with #{region.size} dimensions cannot be canonical over a #{@shape.size} dimensional NArray.")
      end

      # Measure the effect of applied restrictions (if a rule is a number, a dimension
      # gets dropped. If a rule is a range, a dimension gets resized)
      region.each_with_index do |range, axis|
        if range.size > 1
          shape << range.size
        end
      end

      return [1] if shape.empty?
      return shape
    end

    # Returns the `shape` of a region when sampled from this `NArray`.
    # For example, on a 5x5x5 NArray, `measure_shape(1..3, ..., 5)` => `[3, 5]`.
    def measure_region(region) : Array(Int32)
      measure_canonical_region(canonicalize_region(region))
    end

    def each_in_region(region, &block : T, Int32, Int32 ->)
      region = canonicalize_region(region)
      shape = measure_canonical_region(region)

      each_in_canonical_region(region, compute_buffer_step_sizes, &block)
    end

    # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
    # that a step of that size represents.
    # The buffer index of a multidimensional coordinate, x, is equal to x dotted with buffer_step_sizes
    def compute_buffer_step_sizes
      ret = @shape.clone
      ret[-1] = 1

      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * @shape[idx + 1]
      end
      
      ret
    end

    # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
    # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
    # going forwards or backwards.
    # TODO: Better docs
    def iterate_subspace(subspace, step_size, &block : Int32 -> )
      idx = subspace.begin
      if step_size > 0
        while idx <= subspace.end
          yield idx
          idx += step_size
        end
      else
        while idx >= subspace.end
          yield idx
          idx += step_size
        end
      end
    end

    # TODO: Document
    def each_in_canonical_region(region, buffer_step_sizes, axis = 0, read_index = 0, write_index = [0], &block : T, Int32, Int32 -> )
      current_range = region[axis]

      # Base case - yield the scalars in a subspace
      if axis == @shape.size - 1
        current_range.each do |idx|
          yield @buffer[read_index + idx], write_index[0], read_index
          write_index[0] += 1
        end

        return
      end

      # Otherwise, recurse
      buffer_step_size = buffer_step_sizes[axis]
      initial_read_index = read_index

      current_range.each do |idx|
        # navigate to the correct start index
        read_index = initial_read_index + idx * buffer_step_size
        each_in_canonical_region(region, buffer_step_sizes, axis + 1, read_index, write_index) do |a, b, c|
          block.call(a, b, c)
        end
      end
    end

    # each_in_canonical_region(region) do |element, write_index, read_index|
    #   # read_index
    # end

    # def [](*raw_region) : NArray(T)
    #   region, axis_dirs = canonicalize_region(raw_region)
    # end
    
  end
end

module Lattice
  # puts NArray.fill([7,5,3,2], 0).compute_buffer_step_sizes
  size = 40
  shape = [size]*5

  duration = Time.measure do
      arr = NArray.fill(shape, 3f64)
  end

  puts "Creation time: #{duration}"

     
  arr = NArray.fill(shape, 3f64)

  # region = [..., ..., 0, ..., ...]
  # output_slices = [] of NArray(Float64)

  # duration = Time.measure do

  #   slices = (0...arr.shape[2]).map do |slice_number|
  #     region[2] = slice_number
  #     buf = Array(Float64).new(initial_capacity: 40**4)

  #     arr.each_in_region(region) do |elem, write_idx, source_idx|
  #       buf << elem
  #     end

  #     output_slices << NArray.new([40]*4, Slice(Float64).new(pointer: buf.to_unsafe, size: 40**4))
  #   end

  # end
  # puts duration

  regions = [[0,0,..., 1,1], [(size // 4)...(size * 3 // 4), (size // 4)..., ...(size * 3 // 4), ..., ...], [..., ..., ..., ..., ... ]]

  regions.each do  |region|
      duration = Time.measure do
          arr.each_in_region(region) do |elem, idx, source_idx|
            
          end
      end

      puts duration
  end
end