require "./region_iterator"

module Lattice
  class ChunkAndRegionIterator(T)
    # VerboseChunkIterator ?
    # TODO: IndexRegion(Int32) is a needless restriction - find a way to 
    # allow generic coordiate types in the future
    include Iterator(Tuple(MultiIndexable(T), IndexRegion(Int32)))

    @region_spec_iter : RegionIterator
    @src : MultiIndexable(T)

    def self.new(src, chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      new(src, RegionIterator.new(src.shape, chunk_shape, strides, iter, fringe_behaviour))
    end

    def initialize(@src : MultiIndexable(T), @region_spec_iter : RegionIterator)
    end

    def next
      case region = @region_spec_iter.next
      when Stop
        return stop
      else
        {@src.unsafe_fetch_chunk(region), region}
      end
    end

    def next_value
      case region = @region_spec_iter.next
      when Stop
        return stop
      else
        @src.unsafe_fetch_chunk(region)
      end
    end

    def reset
      @region_spec_iter.reset
    end
  end
end
