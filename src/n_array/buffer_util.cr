# A collection of convenience functions and optimizations targeted at multidimensional arrays stored linearly in memory
# (in lexicographic/row major/C order).
# This suggests the concept of a singular "index" representing each element, alongside the multidimensional coordinate.

module Phase
  class NArray(T)
    module BufferUtil

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

      abstract class IndexedStrideIterator(I) < StrideIterator(I)
        @buffer_index : I
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

        protected def initialize(@first, @last, @step, @buffer_step)
          @buffer_index = I.zero
          super(@first, @last, @step)
        end

        def reset : self
          @buffer_index = @buffer_step.map_with_index { |e, i| e * @first[i] }.sum
          super
        end

        def unsafe_next_with_index
          {self.next.unsafe_as(ReadonlyWrapper(I)), @buffer_index}
        end

        def current_index : I
          @buffer_index
        end

        def unsafe_next_index : I
          self.next
          @buffer_index
        end

        macro def_standard_clone
          protected def copy_from(other : self)
            @first = other.@first.clone
            @step = other.@step.clone
            @last = other.@last.clone
            @coord = other.@coord.clone
            @buffer_index = other.@buffer_index
            @buffer_step = other.@buffer_step.clone
            @wrapper = ReadonlyWrapper.new(@coord.to_unsafe, @coord.size)
            self
          end
    
          def clone : self
            inst = {{@type}}.allocate
            inst.copy_from(self)
          end
        end
      end

      class IndexedLexIterator(I) < IndexedStrideIterator(I)
        def_standard_clone

        def advance! : ::Slice(I) | Stop
          (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
            if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
              @buffer_index -= (@coord.unsafe_fetch(i) - @first.unsafe_fetch(i)) * @buffer_step.unsafe_fetch(i)
              @coord[i] = @first.unsafe_fetch(i)
              return stop if i == 0 # most sig
            else
              @coord[i] += @step.unsafe_fetch(i)
              @buffer_index += @buffer_step.unsafe_fetch(i) * @step.unsafe_fetch(i)
              break
            end
          end
          @coord
        end
      end

      class IndexedColexIterator(I) < IndexedStrideIterator(I)
        def_standard_clone

        def advance! : ::Slice(I) | Stop
          0.upto(@coord.size - 1) do |i| # ## least sig .. most sig
            if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
              @buffer_index -= (@coord.unsafe_fetch(i) - @first.unsafe_fetch(i)) * @buffer_step.unsafe_fetch(i)
              @coord[i] = @first.unsafe_fetch(i)
              return stop if i == @coord.size - 1 # most sig
            else
              @coord[i] += @step[i]
              @buffer_index += @buffer_step.unsafe_fetch(i) * @step.unsafe_fetch(i)
              break
            end
          end
          @coord
        end
      end

      # TODO: this should probably have S be a type parameter because it
      # doesn't actually work for all MultiIndexables
      class BufferedECIterator(S, E, I)
        include Iterator(Tuple(E, Indexable(I)))

        @coord_iter : Iterator(Indexable(I))
        @src : S

        delegate :reset, :reverse!, to: @coord_iter

        def self.new(src, iter : Iterator(Indexable(I)))
          BufferedECIterator(typeof(src), typeof(src.first), typeof(src.shape[0])).new(src, coord_iter: iter)
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

        protected def initialize(@src : MultiIndexable(E), @coord_iter : IndexedStrideIterator)
        end

        # Clone the iterator (while maintaining reference to the same source array)
        def clone 
          {{@type}}.new(@src, @coord_iter.clone)
        end

        protected def get_element(coord = nil)
          if (src = @src).responds_to?(:buffer)
            src.buffer.unsafe_fetch(@coord_iter.unsafe_as(IndexedStrideIterator(I)).current_index)
          else
            raise "@src was a MultiIndexable that did not define #buffer. This is likely an issue with Phase or a Phase-compatible library."
          end
        end

        def next
          coord = @coord_iter.next
          return stop if coord.is_a?(Iterator::Stop)
          {get_element(coord), coord}
        end

        def next_value : (E | Stop)
          return stop if @coord_iter.next.is_a?(Stop)
          get_element
        end

        def unsafe_next : Tuple(E, Indexable(I))
          self.next.as(Tuple(E, Indexable(I)))
        end

        def unsafe_next_value : E
          @coord_iter.next
          get_element
        end

        def reverse
          clone.reverse!
        end
      end
    end
  end
end
