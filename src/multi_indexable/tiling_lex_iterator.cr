require "../iterators/stride_iterator"

module Phase
  module MultiIndexable(T)
    private class TilingLexIterator(I) < StrideIterator(I)
      @smaller_shape : Array(I)
      @smaller_coord : Array(I)
      @smaller_coord_wrapper : ReadonlyWrapper(I)

      def_clone

      def initialize(region : IndexRegion(I), @smaller_shape)
        super(region)

        @smaller_coord = global_to_tile(@first)
        @smaller_coord_wrapper = ReadonlyWrapper.new(@smaller_coord.to_unsafe, @smaller_coord.size)
      end

      def self.new(region_literal, smaller_shape)
        idx_r = IndexRegion(typeof(smaller_shape.first)).new(region_literal)
        new(idx_r, smaller_shape)
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

      def advance! : Array(I) | Stop
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
    end
  end
end
