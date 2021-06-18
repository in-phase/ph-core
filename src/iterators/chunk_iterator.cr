require "./chunk_region_iterator.cr"

module Lattice
  class ChunkIterator(T)
    include Iterator(MultiIndexable(T))

    @chunk_and_region_iterator : ChunkAndRegionIterator(T)

    def initialize(@chunk_and_region_iterator : ChunkAndRegionIterator(T))
    end

    def self.new(src, chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
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
