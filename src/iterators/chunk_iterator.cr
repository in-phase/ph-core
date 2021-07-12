require "./chunk_region_iterator.cr"

module Lattice
  class ChunkIterator(E, I)
    include Iterator(MultiIndexable(E))

    @chunk_and_region_iterator : ChunkAndRegionIterator(E, I)

    def initialize(@chunk_and_region_iterator : ChunkAndRegionIterator(E, I))
    end

    def self.new(src, chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, fringe_behaviour : RegionIterator::FringeBehaviour = RegionIterator::FringeBehaviour::DISCARD)
      new(ChunkAndRegionIterator.new(src, chunk_shape, strides, iter, fringe_behaviour))
    end

    def next
      @chunk_and_region_iterator.next_value
    end

    def reset
      @chunk_and_region_iterator.reset
    end
  end
end
