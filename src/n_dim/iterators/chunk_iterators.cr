require "../region_helpers"

module Lattice
  module MultiIndexable(T)

    class ChunkAndRegionIterator(T)
        include Iterator(Tuple(MultiIndexable(T), Array(RegionHelpers::SteppedRange)))

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
            {@src.unsafe_fetch_region(region), region}
          end
        end

        def next_value
          case region = @region_spec_iter.next
          when Stop
            return stop
          else
            @src.unsafe_fetch_region(region)
          end
        end

        def reset
          @region_spec_iter.reset
        end
    end

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
    
    

    # CoordIterator -> CoordIterator
    # ChunkIterator (Iterates over a region, yielding the region specifiers that can be made from a box and a stride) -> RegionSpecIterator
    
    # ElemIterator -> ElemIterator
    # New ChunkIterator XVII (Iterates over a region, yielding regions) -> RegionIterator
    
    # ElemAndCoordIterator (Iterates over a region, yielding elements and their coordinates) -> ElemAndCoordIterator
    # "New ChunkIterator??" (Iterates over a region, yielding regions, the region specifiers they came from) ->

    

    class RegionIterator
      include Iterator(Array(RegionHelpers::SteppedRange))

      @src_shape : Array(Int32)
      @chunk_shape : Array(Int32)
      @coord_iter : CoordIterator

      @fringe_behaviour : FringeBehaviour   
      # getter size : Int32

      def self.new(src_shape : Array(Int32), chunk_shape, strides = nil, iter : CoordIterator.class = LexIterator, fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
        # convert strides into an iterable region
        strides ||= chunk_shape
        if strides.any? { |x| x <= 0 }
          raise DimensionError.new("Stride size must be greater than 0.")
        end
        last = self.compute_lasts(src_shape, chunk_shape, strides, fringe_behaviour)

        coord_iter = iter.from_canonical(Array(Int32).new(src_shape.size, 0), last, strides)

        new(src_shape, chunk_shape, coord_iter, fringe_behaviour)
      end

      def self.from_canonical(src_shape, chunk_shape, coord_iter, fringe_behaviour)
        new(src_shape, chunk_shape, coord_iter, fringe_behaviour)
      end

      def initialize(@src_shape, @chunk_shape, @coord_iter, @fringe_behaviour)
      end

      # protected def initialize(@src_shape, @chunk_shape, first, last, strides, @fringe_behaviour)
      #   @coord_iter = iter.from_canonical(Array(Int32).new(0, @src_shape.size), last, strides)
      # end

      # stride 1    stride 2    stride 3
      # x x x x x   x x x x x   x x x x x 
      # o o o       o o o       o o o
      #   o o o         o o o   ^    (o o)
      #     o o o       ^  (o)          
      #     ^          
      # Returns the starting index of the last full chunk you can fit in an axis
      protected def self.complete_chunks(size, stride, chunk)
        (size - chunk) // stride
      end

      protected def self.chunks(size, stride, chunk = nil)
        (size - 1) // stride
      end
  
      protected def self.compute_lasts(src_shape, chunk_shape, strides, fringe_behaviour)

        # case fringe_behaviour
        # when FringeBehaviour::COVER
        #   last = src_shape.map_with_index do |size, i|
        #     strides[i] < chunk_shape[i] ? self.last_complete_chunk(size, strides[i], chunk_shape[i]) : last_chunk(size, strides[i])
        #   end
        # when FringeBehaviour::ALL_START_POINTS
        #   last = src_shape.map_with_index { |size, i| last_chunk(size, strides[i]) }
        # when FringeBehaviour::DISCARD
        #   last = src_shape.map_with_index do |size, i|
        #     last_complete_chunk(size, strides[i], chunk_shape[i])
        #   end
        # else
        #   raise NotImplementedError.new("Could not get next chunk: Unrecognized FringeBehaviour type")
        # end
        case fringe_behaviour
        when FringeBehaviour::COVER
          src_shape.map_with_index do |size, i|
            if strides[i] < chunk_shape[i]
              strides[i] * complete_chunks(size, strides[i], chunk_shape[i])
            else
              strides[i] * chunks(size, strides[i])
            end
            # (size - (strides[i] < chunk_shape[i] ? chunk_shape[i] : 1)) // strides[i] * strides[i]
          end
        when FringeBehaviour::ALL_START_POINTS
          src_shape.map_with_index do |size, i|
            strides[i] * chunks(size, strides[i])
            # (size - 1) // strides[i] * strides[i]
          end
        when FringeBehaviour::DISCARD
          src_shape.map_with_index do |size, i|
            strides[i] * complete_chunks(size, strides[i], chunk_shape[i])
            # (size - chunk) // strides[i] * strides[i]
          end
        else
          raise NotImplementedError.new("Could not get next chunk: Unrecognized FringeBehaviour type")
        end
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

      def reset 
        @coord_iter.reset
      end

      enum FringeBehaviour
        DISCARD
        COVER
        ALL_START_POINTS
      end
    end
  end
end
