module Phase
  module MultiIndexable(T)
    # Iterates over chunks of a `MultiIndexable` by dropping the region
    # value from `ChunkAndRegionIterator.next`.
    private class ChunkIterator(C, E, I)
      include Iterator(C)

      alias FB = RegionIterator::FringeBehaviour

      @chunk_and_region_iterator : ChunkAndRegionIterator(C, E, I)

      def_clone
      delegate :reset, to: @chunk_and_region_iterator

      def initialize(@chunk_and_region_iterator : ChunkAndRegionIterator(C, E, I))
      end

      def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                  fringe_behaviour : FB = FB::DISCARD, &block)
        new(ChunkAndRegionIterator.new(src, chunk_shape, strides, degeneracy, fringe_behaviour) { |region| yield region })
      end

      def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                  fringe_behaviour : FB = FB::DISCARD)
        new(ChunkAndRegionIterator.new(src, chunk_shape, strides, degeneracy, fringe_behaviour))
      end

      def next : C | Stop
        @chunk_and_region_iterator.next_value
      end
    end
  end
end
