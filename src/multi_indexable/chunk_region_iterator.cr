module Phase
  class ChunkAndRegionIterator(C, E, I)
    include Iterator(Tuple(C, IndexRegion(I)))

    alias FB = RegionIterator::FringeBehaviour

    @region_iter : RegionIterator(I)
    @src : MultiIndexable(E)

    delegate :reset, to: @region_iter

    def self.new(src : MultiIndexable, chunk_shape : Shape, strides : Coord? = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD, &block)
      region_iter = RegionIterator.new(src.shape, chunk_shape, strides, degeneracy, fringe_behaviour) { |region| yield region }
      from(src, region_iter)
    end

    def self.new(src : MultiIndexable, chunk_shape : Shape, strides : Coord? = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD)
      region_iter = RegionIterator.new(src.shape, chunk_shape, strides, degeneracy, fringe_behaviour)
      from(src, region_iter)
    end

    protected def self.from(src : MultiIndexable(E), region_iter : RegionIterator(I))
      ChunkAndRegionIterator(typeof(src.unsafe_fetch_chunk(region_iter.unsafe_next)), E, I).new(src, region_iter)
    end

    def initialize(@src : MultiIndexable(E), @region_iter : RegionIterator(I))
    end

    def clone 
      {{@type}}.new(@src, @region_iter.clone)
    end

    def next : Stop | Tuple(C, IndexRegion(I))
      case region = @region_iter.next
      in IndexRegion
        chunk = @src.unsafe_fetch_chunk(region).as(C)
        {chunk, region}
      in Stop
        stop
      end
    end

    def next_value : Stop | C
      case maybe_tuple = self.next
      in Tuple
        maybe_tuple[0]
      in Stop
        stop
      end
    end

  end
end
