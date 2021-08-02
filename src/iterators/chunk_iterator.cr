require "./chunk_region_iterator.cr"

module Phase
  class ChunkIterator(E, I)
    include Iterator(MultiIndexable(E))

    alias FB = RegionIterator::FringeBehaviour

    @chunk_and_region_iterator : ChunkAndRegionIterator(E, I)

    def initialize(@chunk_and_region_iterator : ChunkAndRegionIterator(E, I))
    end

    def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD, &block)
      new(ChunkAndRegionIterator.new(src, chunk_shape, strides, degeneracy, fringe_behaviour) { |region| yield region })
    end

    def self.new(src, chunk_shape, strides = nil, degeneracy = nil,
                 fringe_behaviour : FB = FB::DISCARD)
      new(ChunkAndRegionIterator.new(src, chunk_shape, strides, degeneracy, fringe_behaviour))
    end

    def next : MultiIndexable(E) | Stop
      case val = @chunk_and_region_iterator.next_value
      when MultiIndexable(E)
        # HACK: mitigates virtual type issues https://forum.crystal-lang.org/t/virtual-types-causing-unexpected-behaviour/3584
        val.unsafe_as(MultiIndexable(E))
      else
        stop
      end
    end

    def reset
      @chunk_and_region_iterator.reset
    end
  end
end
