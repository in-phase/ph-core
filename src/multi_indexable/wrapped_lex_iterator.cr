require "../iterators/coord_iterator.cr"

module Phase
  module MultiIndexable
    private class WrappedLexIterator(T) < CoordIterator(T)
      getter smaller_coord : Array(T)
      @smaller_shape : Array(T)

      def initialize(region : IndexRegion(T), @smaller_shape)
        super(region)
        @smaller_coord = wrap_coord(@first)
      end

      def initialize(region_literal, @smaller_shape)
        super(IndexRegion(T).new(region_literal))
        @smaller_coord = wrap_coord(@first)
      end

      def clone 
        raise "Can't clone private class WrappedLexIterator(T)"
      end

      def wrap_coord(coord)
        coord.map_with_index { |axis, idx| axis % @smaller_shape[idx] }
      end

      def advance_coord
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
