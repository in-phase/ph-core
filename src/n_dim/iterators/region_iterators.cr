require "./coord_iterators"
require "../multi_indexable"

module Lattice
  module MultiIndexable(T)
    abstract class RegionIterator(A,T,I)
      include Iterator(Tuple(T, Array(Int32)))

      @coord_iter : I

      # def self.of(@narr, region, reverse, colex)
      # end

      def initialize(@narr : A, region = nil, reverse = false)
        @coord_iter = I.new(@narr.shape, region, reverse)
      end

      def reset
        @coord_iter.reset
      end

      def next
        coord = @coord_iter.next
        return stop if coord.is_a?(Iterator::Stop)
        {@narr.unsafe_fetch_element(coord), coord}
      end
      
      def next_value : (T | Iterator::Stop)
        coord = @coord_iter.next
        return stop if coord.is_a?(Iterator::Stop)
        @narr.unsafe_fetch_element(coord)
      end

      def unsafe_next_value : T
        coord = @coord_iter.next.unsafe_as(Array(Int32))
        @narr.unsafe_fetch_element(coord)
      end
    end

    class LexRegionIterator(A,T) < RegionIterator(A,T,LexIterator)
    end

    class ColexRegionIterator(A,T) < RegionIterator(A,T,ColexIterator)
    end
  end
end
