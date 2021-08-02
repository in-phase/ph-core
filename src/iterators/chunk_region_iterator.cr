require "./region_iterator"

module Phase
  class ChunkAndRegionIterator(E, I)
    # VerboseChunkIterator ?
    # TODO: IndexRegion(Int32) is a needless restriction - find a way to
    # allow generic coordiate types in the future
    include Iterator(Tuple(MultiIndexable(E), IndexRegion(I)))
    alias FB = RegionIterator::FringeBehaviour

    @region_iter : RegionIterator(I)
    @src : MultiIndexable(E)

    # TODO: change from classes to instances of iter
    def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD, &block)
      new(src, RegionIterator.new(src.shape, chunk_shape, strides, degeneracy, fringe_behaviour) { |region| yield region })
    end

    def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD)
      new(src, RegionIterator.new(src.shape, chunk_shape, strides, degeneracy, fringe_behaviour))
    end

    def initialize(@src : MultiIndexable(E), @region_iter : RegionIterator(I))
    end

    def next : Stop | Tuple(MultiIndexable(E), IndexRegion(I))
      case region = @region_iter.next
      when Stop
        return stop
      else
        {@src.unsafe_fetch_chunk(region, drop: true), region}
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
