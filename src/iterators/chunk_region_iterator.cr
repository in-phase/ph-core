require "./region_iterator"

module Lattice
  class ChunkAndRegionIterator(E, I)
    # VerboseChunkIterator ?
    # TODO: IndexRegion(Int32) is a needless restriction - find a way to 
    # allow generic coordiate types in the future
    include Iterator(Tuple(MultiIndexable(E), IndexRegion(I)))

    @region_iter : RegionIterator(I)
    @src : MultiIndexable(E)

    # TODO: change from classes to instances of iter
    def self.new(src, chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      new(src, RegionIterator.new(src.shape, chunk_shape, strides, iter, fringe_behaviour))
    end

    def initialize(@src : MultiIndexable(E), @region_iter : RegionIterator(I))
    end

    def next
      case region = @region_iter.next
      when Stop
        return stop
      else
        {@src.unsafe_fetch_chunk(region), region}
      end
    end

    def next_value
      case region = @region_iter.next
      when Stop
        return stop
      else
        @src.unsafe_fetch_chunk(region)
      end
    end

    def reset
      @region_iter.reset
    end
  end
end
