require "../region_helpers"

module Lattice
  module MultiIndexable(T)
    class ChunkyRegionIterator(T)
        include Iterator(Tuple(MultiIndexable(T), Array(RegionHelpers::SteppedRange)))

        @region_spec_iter : RegionSpecIterator
        
        
    end

    class ChunkyElemIterator(T)
        include Iterator(MultiIndexable(T))
        
    end

    # CoordIterator -> CoordIterator
    
    # ElemIterator -> ElemIterator
    
    # RegionIterator (Iterates over a region, yielding elements and their coordinates) -> ???
    
    # "New ChunkIterator??" (Iterates over a region, yielding regions, the region specifiers they came from) ->
    # ChunkIterator (Iterates over a region, yielding the region specifiers that can be made from a box and a stride) -> RegionSpecIterator
    # New ChunkIterator XVII (Iterates over a region, yielding regions) ->

    
    # {@narr.get_region(region), region}

    class RegionSpecIterator
      include Iterator(Array(RegionHelpers::SteppedRange))

      @chunk_shape : Array(Int32)
      @coord_iter : Array(Int32)

      def initialize(@src_shape, @chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, @fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
        # convert strides into an iterable region
        @strides = strides || @chunk_shape
        if @strides.any? { |x| x <= 0 }
          raise DimensionError.new("Stride size must be greater than 0.")
        end

        @empty = @src_shape.any?(0)

        case @fringe_behaviour
        when FringeBehaviour::COVER
          @last = @src_shape.map_with_index do |size, i|
            @strides[i] < @chunk_shape[i] ? last_complete_chunk(size, @strides[i], @chunk_shape[i]) : size - 1
          end
        when FringeBehaviour::ALL_START_POINTS
          last = @src_shape.map { |size| size - 1 }
        when FringeBehaviour::DISCARD
          last = @src_shape.map_with_index do |size, i|
            last_complete_chunk(size, strides[i], @chunk_shape[i])
          end
        else
          raise NotImplementedError.new("Could not get next chunk: Unrecognized FringeBehaviour type")
        end

        @coord_iter = iter.from_canonical(Array(Int32).new(0, @src_shape.size), last, strides)
      end

      # x x x x x
      # o o o
      #   o o o
      #     o o o
      #     ?  
      # Returns the starting index of the last full chunk you can fit in an axis
      protected def last_complete_chunk(size, stride, chunk)
        points = size - chunk
        points - (points % stride)
      end

      protected def compute_region(coord)
        region = RegionHelpers.translate_shape(@chunk_shape, coord, @src_shape)
        unless @fringe_behaviour == FringeBehaviour::DISCARD
            region = RegionHelpers.trim_region(region, @src_shape)
        end
        return region
      end

      def next
        coord = @coord_iter.next
        case coord
        when Stop
          return stop
        else
          compute_region(coord)
        end
      end

      def unsafe_next
        compute_region(@coord_iter.next)
      end

      enum FringeBehaviour
        DISCARD
        COVER
        ALL_START_POINTS
      end
    end
  end
end
