# A collection of convenience functions and optimizations targeted at multidimensional arrays stored linearly in memory
# (in lexicographic/row major/C order).
# This suggests the concept of a singular "index" representing each element, alongside the multidimensional coordinate.

require "../n_dim/iterators/*"
require "../n_dim/iterators/region_iterators.cr"

module Lattice
  class NArray(T)
    include MultiIndexable(T)

    # TODO: decide
    # move coord_to_index/index_to_coord here? at least static versions?
    # move out of NArray? To own namespace?

    # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
    # that a step of that size represents.
    # The buffer index of a multidimensional coordinate, x, is equal to x dotted with axis_strides
    def self.axis_strides(shape)
      ret = shape.clone
      ret[-1] = 1

      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * shape[idx + 1]
      end

      ret
    end

    abstract class IndexedCoordIterator < MultiIndexable::CoordIterator
      @buffer_index : Int32 = 0 # Initialized beforehand to placate the compiler
      @buffer_step : Array(Int32)

      protected def initialize(shape, region = nil, reverse : Bool = false)
        @buffer_step = NArray.axis_strides(shape)
        super(shape, region, reverse)
      end

      def unsafe_next_with_index
        {self.next.unsafe_as(Array(Int32)), @buffer_index}
      end

      def current_index : Int32
        @buffer_index
      end

      def unsafe_next_index : Int32
        self.next
        @buffer_index
      end

      def setup_buffer_index(decrement_axis)
        @buffer_index = @buffer_step.map_with_index { |e, i| e * @first[i] }.sum
        @buffer_index -= @buffer_step[decrement_axis] * @step[decrement_axis]
      end
    end

    class IndexedLexIterator < IndexedCoordIterator
      
      def reset : self
        setup_coord(CoordIterator::LEAST_SIG)
        setup_buffer_index(CoordIterator::LEAST_SIG)
        self
      end

      def next_if_nonempty
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @buffer_index -= (@coord[i] - @first[i]) * @buffer_step[i]
            @coord[i] = @first[i]
            return stop if i == 0 # most sig
          else
            @coord[i] += @step[i]
            @buffer_index += @buffer_step[i] * @step[i]
            break
          end
        end
        @coord
      end
    end

    class IndexedColexIterator < IndexedCoordIterator
      def reset : self
        setup_coord(CoordIterator::MOST_SIG)
        setup_buffer_index(CoordIterator::MOST_SIG)
        self
      end

      def next_if_nonempty
        0.upto(@coord.size - 1) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @buffer_index -= (@coord[i] - @first[i]) * @buffer_step[i]
            @coord[i] = @first[i]
            return stop if i == @coord.size - 1 # most sig
          else
            @coord[i] += @step[i]
            @buffer_index += @buffer_step[i] * @step[i]
            break
          end
        end
        @coord
      end
    end

    class BufferedRegionIterator(T) < MultiIndexable::RegionIterator(T)    
      
      def self.new(src, region = nil, reverse = false, iter : CoordIterator.class = IndexedLexIterator) : self
        raise "BufferedRegionIterators must use IndexedCoordIterators" unless iter < IndexedCoordIterator
        new(src, iter.new(src.shape, region, reverse))
      end

      protected def get_element(coord = nil)
        @src.buffer.unsafe_fetch(@coord_iter.unsafe_as(IndexedCoordIterator).current_index)
      end

      def next_value : (T | Stop)
        return stop if @coord_iter.next.is_a?(Stop)
        get_element
      end

      def unsafe_next_value : T
        get_element
      end
    end
  end
end
