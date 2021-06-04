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
      @buffer_index : Int32
      @buffer_step : Array(Int32)

      def initialize(shape, region = nil, reverse : Bool = false)
        super(shape, region, reverse)
        @buffer_step = NArray.axis_strides(shape)
        @buffer_index = @buffer_step.map_with_index { |e, i| e * @first[i] }.sum
        @buffer_index = setup_buffer_index(@buffer_index, @buffer_step, @step)
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
    end

    class IndexedLexIterator < IndexedCoordIterator
      def setup_buffer_index(buffer_index, buffer_step, step)
        buffer_index -= buffer_step[-1] * step[-1]
        buffer_index
      end

      def setup_coord(coord, step)
        coord[-1] -= step[-1]
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
      def setup_coord(coord, step)
        coord[0] -= step[0]
      end

      def setup_buffer_index(buffer_index, buffer_step, step)
        buffer_index -= buffer_step[0] * step[0]
        buffer_index
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

    abstract class BufferedRegionIterator(T) < MultiIndexable::RegionIterator(T)
      def next
        coord = @coord_iter.next
        return stop if coord.is_a?(Stop)
        {@narr.buffer.unsafe_fetch(@coord_iter.current_index), coord}
      end

      def next_value : (T | Stop)
        return stop if @coord_iter.next.is_a?(Stop)
        @narr.buffer.unsafe_fetch(@coord_iter.current_index)
      end

      def unsafe_next_value : T
        @narr.buffer.unsafe_fetch(@coord_iter.unsafe_next_index)
      end
    end
  end
end
