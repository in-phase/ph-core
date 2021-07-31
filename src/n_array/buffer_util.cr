# A collection of convenience functions and optimizations targeted at multidimensional arrays stored linearly in memory
# (in lexicographic/row major/C order).
# This suggests the concept of a singular "index" representing each element, alongside the multidimensional coordinate.

module Phase
  class NArray(T)
    module BufferUtil
      # TODO: decide
      # move coord_to_index/index_to_coord here? at least static versions?
      # move out of NArray? To own namespace?

      # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
      # that a step of that size represents.
      # The buffer index of a multidimensional coordinate, x, is equal to x dotted with axis_strides
      def self.axis_strides(shape)
        ret = shape.clone
        ret[-1] = typeof(shape[0]).zero + 1

        ((ret.size - 2)..0).step(-1) do |idx|
          ret[idx] = ret[idx + 1] * shape[idx + 1]
        end

        ret
      end

      # Convert from n-dimensional indexing to a buffer location.
      def coord_to_index(coord) : Int
        coord = CoordUtil.canonicalize_coord(coord, @shape)
        {{@type}}.coord_to_index_fast(coord, @shape, @axis_strides)
      end

      # TODO: Talk about what this should be named
      def self.coord_to_index(coord, shape) : Int
        coord = CoordUtil.canonicalize_coord(coord, shape)
        steps = axis_strides(shape)
        {{@type}}.coord_to_index_fast(coord, shape, steps)
      end

      # Assumes coord is canonical
      def self.coord_to_index_fast(coord, shape, axis_strides) : Int
        index = typeof(shape[0]).zero
        coord.each_with_index do |elem, idx|
          index += elem * axis_strides[idx]
        end
        index
      rescue exception
        raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this {{@type}} along at least one dimension.")
      end

      # Convert from a buffer location to an n-dimensional coord
      def index_to_coord(index) : Array
        typeof(self).index_to_coord(index, @shape)
      end

      # OPTIMIZE: This could (maybe) be improved with use of `axis_strides`
      def self.index_to_coord(index, shape) : Array
        if index > shape.product
          raise IndexError.new("Cannot convert index to coordinate: the given index is out of bounds for this {{@type}} along at least one dimension.")
        end
        coord = shape.dup # <- untested; was: Array(Int32).new(shape.size, typeof(shape[0]).zero)
        shape.reverse.each_with_index do |length, dim|
          coord[dim] = index % length
          index //= length
        end
        coord.reverse
      end

      abstract class IndexedCoordIterator(I) < CoordIterator(I)
        @buffer_index : I # Initialized beforehand to placate the compiler
        @buffer_step : Array(I)

        def self.cover(shape)
          new(IndexRegion.cover(shape), shape)
        end

        protected def initialize(region : IndexRegion(I), shape : Shape)
          if region.dimensions == 0
            raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
          end
          @buffer_index = I.zero
          @buffer_step = BufferUtil.axis_strides(shape)
          super(region)
        end

        protected def initialize(@first, @last, @step, @size, @buffer_step)
          @buffer_index = I.zero
          super(@first, @last, @step, @size)
        end

        def reset : self
          @buffer_index = @buffer_step.map_with_index { |e, i| e * @first[i] }.sum
          super
        end

        def unsafe_next_with_index
          {self.next.unsafe_as(Array(I)), @buffer_index}
        end

        def current_index : I
          @buffer_index
        end

        def unsafe_next_index : I
          self.next
          @buffer_index
        end
      end

      class IndexedLexIterator(I) < IndexedCoordIterator(I)
        def_clone

        def advance_coord
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

      class IndexedColexIterator(I) < IndexedCoordIterator(I)
        def_clone

        def advance_coord
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

      # TODO: Make generic coord
      # TODO: this should probably have S be a type parameter because it
      # doesn't actually work for all MultiIndexables
      class BufferedECIterator(T, I) < ElemAndCoordIterator(T, I)
        # This is needed here to prevent the method below (def self.of(src, region = nil)) from taking priority
        def self.of(src, iter : CoordIterator(I))
          new(src, iter)
        end

        # Overridden to replace default iterator type
        def self.of(src, region = nil)
          if region.nil?
            iter = IndexedLexIterator.cover(src.shape)
          else
            iter = IndexedLexIterator.new(region, src.shape)
          end
          new(src, iter)
        end

        protected def initialize(@src : MultiIndexable(T), @coord_iter : CoordIterator(I))
          raise "BufferedECIterators must use IndexedCoordIterators" unless @coord_iter.is_a?(IndexedCoordIterator(I))
        end

        protected def get_element(coord = nil)
          if (src = @src).responds_to?(:buffer)
            src.buffer.unsafe_fetch(@coord_iter.unsafe_as(IndexedCoordIterator(I)).current_index)
          else
            # TODO
            raise "bad error"
          end
        end

        def next_value : (T | Stop)
          return stop if @coord_iter.next.is_a?(Stop)
          get_element
        end

        def unsafe_next_value : T
          @coord_iter.next
          get_element
        end
      end
    end
  end
end
