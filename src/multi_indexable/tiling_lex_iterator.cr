require "../iterators/stride_iterator"

module Phase
  module MultiIndexable(T)
    class TilingLexIterator(I) < StrideIterator(I)
      @smaller_shape : Array(I)
      @smaller_coord : Array(I)
      @smaller_coord_wrapper : ReadonlyWrapper(I)

      private def initialize(@first : Array(I), @step : Array(Int32), @last : Array(I), @smaller_shape : Array(I))
        super(@first, @step, @last)

        @smaller_coord = global_to_tile(@first)
        @smaller_coord_wrapper = ReadonlyWrapper.new(@smaller_coord.to_unsafe, @smaller_coord.size)
      end

      def self.new(region : IndexRegion(I), smaller_shape)
        new(region.@first, region.@step, region.@last, smaller_shape)
      end

      def self.new(region_literal, smaller_shape)
        idx_r = IndexRegion(typeof(smaller_shape.first)).new(region_literal)
        
        new(idx_r, smaller_shape)
      end

      def advance! : ::Slice(I) | Stop
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @coord[i] = @first[i]
            @smaller_coord[i] = @coord[i] % @smaller_shape[i]
            return stop if i == 0 # most sig
          else
            @coord[i] += @step[i]
            @smaller_coord[i] = @coord[i] % @smaller_shape[i]
            break
          end
        end

        @coord
      end

      def smaller_coord : Indexable(I)
        @smaller_coord_wrapper
      end

      def wrap_coord(coord)
        coord.map_with_index { |axis, idx| axis % @smaller_shape[idx] }
      end

      def global_to_tile(coord)
        coord.map_with_index { |axis, idx| axis % @smaller_shape[idx] }
      end

      protected def copy_from(other : self)
        @first = other.@first.clone
        @step = other.@step.clone
        @last = other.@last.clone
        @coord = other.@coord.clone
        @smaller_shape = other.@smaller_shape.clone
        @smaller_coord = other.@smaller_coord.clone
        @smaller_coord_wrapper = ReadonlyWrapper.new(@smaller_coord.to_unsafe, @coord.size)
        @wrapper = ReadonlyWrapper.new(@coord.to_unsafe, @coord.size)

        self
      end

      def clone : self
        inst = {{@type}}.allocate
        inst.copy_from(self)
      end
    end
  end
end
