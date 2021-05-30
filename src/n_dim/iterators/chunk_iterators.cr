require "../region_helpers"

module Lattice
    module MultiIndexable(T)
        class ChunkIterator(A, T)
            include Iterator(Tuple(MultiIndexable(T), Array(RegionHelpers::SteppedRange)))
    
            @chunk_shape : Array(Int32)
            @strides : Array(Int32)
            @last : Array(Int32)
            @coord : Array(Int32)
            @empty : Bool = false
    
            def initialize(@narr : A, @chunk_shape, strides = nil, @fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
            # convert strides into an iterable region
            @strides = strides || @chunk_shape
            if @strides.any? {|x| x <= 0}
                raise DimensionError.new("Stride size must be greater than 0.")
            end
    
            @coord = [0] * @narr.dimensions
            @coord[-1] -= @strides[-1]
    
            @empty = @narr.shape.any?(0)
    
            case @fringe_behaviour
            when FringeBehaviour::COVER
                @last = @narr.shape.map_with_index do |size, i|
                @strides[i] < @chunk_shape[i] ? last_complete_chunk(size, @strides[i], @chunk_shape[i]) : size - 1
                end
            when FringeBehaviour::ALL_START_POINTS
                @last = @narr.shape.map {|size| size - 1}
            when FringeBehaviour::DISCARD
                @last = @narr.shape.map_with_index do |size, i|
                last_complete_chunk(size, @strides[i], @chunk_shape[i])
                end
            else
                raise NotImplementedError.new("Could not get next chunk: Unrecognized FringeBehaviour type")
            end
            end
    
            protected def last_complete_chunk(size, stride, chunk)
            points = size - chunk
            points - (points % stride)
            end
    
            def next
            return stop if @empty
            unsafe_next
            end
    
            def unsafe_next
            (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
                @coord[i] += @strides[i]
                break if @coord[i] <= @last[i]
    
                @coord[i] = 0
                return stop if i == 0 # most sig
            end
            
            region = RegionHelpers.translate_shape(@chunk_shape, @coord, @narr.shape)
            
            unless @fringe_behaviour == FringeBehaviour::DISCARD
                region = RegionHelpers.trim_region(region, @narr.shape)
            end
    
            return {@narr.get_region(region), region}
            end
    
            # TODO: This is a pretty general concept - it might be useful to define it at a broader
            # scope with less specific naming
            enum FringeBehaviour
            DISCARD;
            COVER;
            ALL_START_POINTS
            end
        end
    end
end