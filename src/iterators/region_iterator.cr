module Phase
  class RegionIterator(I)
    include Iterator(IndexRegion)

    @src_shape : Array(I)
    @chunk_shape : Array(I)
    @coord_iter : CoordIterator(I)

    @fringe_behaviour : FringeBehaviour
    @degeneracy : Array(Bool)

    # getter size : Int32
    # TODO: iter inputs, etc
    def self.new(src_shape : Indexable(I), chunk_shape = nil, strides = nil, degeneracy = nil,
                 fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD, &block : IndexRegion(I) -> CoordIterator(I))
      # convert strides into an iterable region
      strides ||= chunk_shape
      if strides.any? { |x| x <= 0 }
        raise DimensionError.new("Stride size must be greater than 0.")
      end

      last = self.compute_lasts(src_shape, chunk_shape, strides, fringe_behaviour)
      region = IndexRegion.new(Array(I).new(src_shape.size, 0), strides, last: last)
      coord_iter = yield region

      new(src_shape, chunk_shape, coord_iter, degeneracy, fringe_behaviour)
    end

    def self.new(src_shape : Indexable(I), chunk_shape, strides = nil, degeneracy = nil,
                 fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      new(src_shape, chunk_shape, strides, degeneracy, fringe_behaviour) do |region|
        LexIterator.new(region)
      end
    end

    protected def initialize(@src_shape : Indexable(I), @chunk_shape, @coord_iter : CoordIterator(I), degeneracy : Array(Bool)? = nil, @fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      @degeneracy = degeneracy || Array.new(@src_shape.size, false)
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
      region = IndexRegion.cover(@chunk_shape, drop: true, degeneracy: @degeneracy.clone)
      region.translate!(coord)

      unless @fringe_behaviour == FringeBehaviour::DISCARD
        region.trim!(@src_shape)
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
