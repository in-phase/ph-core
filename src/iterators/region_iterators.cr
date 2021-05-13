


# iterates over slices (any axis)
# iterating 3x3 kernels

# remainders: discard? pass, unfilled?

[a b c d e f g]
=> a b c 
=> d e f 
=> discard g


narr.get(coord, size)
narr.get_available


[1..3..9, 2..4]

make a chunkiter and give me regions with shape [3, 2]
narr.chunkiter(3, 3) &[1..2..3, ...]


chunkiter(shape, )

narr.chunks(chunk_shape, strides) # => ChunkIterator(NArray(T)), expensive and slow, safe
narr.view.chunks(chunk_shape, strides) # => ChunkIterator(View(T)), fast and cheap, iffy

..3...


[1,2,3
4,5,6
7,8,9
10,11,12
13,14,15]

=>
[1,2,3
7,8,9]

=> 
[4,5,6
10,11,12]






module Lattice
  module MultiIndexable(T)
    abstract class RegionIterator(A, T)
      include Iterator(Tuple(T, Array(Int32)))
      
      @coord : Array(Int32)

      @first : Array(Int32)
      @last : Array(Int32)
      @step : Array(Int32)

      def initialize(@narr : A, region = nil, reverse = false)
        if region
          @first = Array(Int32).new(initial_capacity: region.size)
          @last = Array(Int32).new(initial_capacity: region.size)
          @step = Array(Int32).new(initial_capacity: region.size)

          region.each do |range|
            @first << range.begin
            @step << range.step
            @last << range.end
          end
        else
          @first = [0] * @narr.dimensions
          @last = @narr.shape.map &.pred
          @step = [1] * @narr.dimensions
        end

        if reverse
          @last, @first = @first, @last
          @step.map! &.-
        end

        @coord = @first.dup
        setup_coord(@coord, @step)
      end

      protected def initialize(@narr, @first, @last, @step)
        @coord = @first.dup
        setup_coord(@coord, @step)
      end

      def reset
        @coord = @first.dup
        setup_coord(@coord, @step)
      end

      def reverse!
        @last, @first = @first, @last
        @step.map! &.-

        @coord = @first.dup
        setup_coord(@coord, @step)
        self
      end

      def reverse
        typeof(self).new(@narr, @last, @first, @step.map &.-)
      end

      abstract def setup_coord(coord, step)
      abstract def next
    end

    class LexRegionIterator(A, T) < RegionIterator(A, T)
      def setup_coord(coord, step)
        coord[-1] -= step[-1]
      end

      def next
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @coord[i] = @first[i]
            return stop if i == 0 # most sig
          else
            @coord[i] += @step[i]
            break
          end
        end
        {@narr.unsafe_fetch_element(@coord), @coord}
      end
    end

    class ColexRegionIterator(A, T) < RegionIterator(A, T)
      def setup_coord(coord, step)
        coord[0] -= step[0]
      end

      def next
        @coord.each_index do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @coord[i] = @first[i]
            return stop if i == @coord.size - 1 # most sig
          else
            @coord[i] += @step[i]
            break
          end
        end
        {@narr.unsafe_fetch_element(@coord), @coord}
      end
    end
  end
end
