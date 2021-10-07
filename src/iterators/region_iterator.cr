require "../index_region.cr"

module Phase
  # `RegionIterator` iterates over all `IndexRegion`s with a given *chunk_shape* whose
  # coordinates lie within a given *src_shape*. For example:
  #
  # ```crystal
  # iter = RegionIterator.new(src_shape: [2, 5], chunk_shape: [1, 2]) # the parameter names are only included for clarity
  # iter.next # => [0..0, 0..1]
  # iter.next # => [0..0, 2..3]
  # iter.next # => [1..1, 0..1]
  # iter.next # => [1..1, 2..3]
  # ```
  #
  # The example above is very simple in that it leaves most of the options as their defaults.
  # Notice that the regions produced have no overlap - this is because the default
  # vertex stride is equal to the chunk shape.
  #
  # `RegionIterator` also provides ways to control the iteration order, its
  # behaviour at the boundary (note that in the above example, column 4 is
  # totally excluded because two columns did not evenly divide five), and
  # dimension dropping (see `IndexRegion` for details).
  class RegionIterator(I)
    include Iterator(IndexRegion(I))

    # The shape of the space that `RegionIterator` will iterate over. In all
    # practical cases, this should be the larger of your two shapes.
    @src_shape : Array(I)

    # The shape of the `IndexRegion`s that `#next` will attempt to return.
    # Depending on your choice of *fringe_behaviour*, this shape may be
    # exact or just an upper bound.
    @chunk_shape : Array(I)

    # TODO: I think we're checking for out-of-bounds coords already, but
    # if not we should either implement that or limit this to StrideIterator
    # update: we aren't checking bounds of the start coord and need to do so.
    # I think start coord out of bounds => raise, and if it's a StrideIterator,
    # it checks the largest_coord and raises at construction time rather than
    # iteration time 
    @coord_iter : Iterator(Indexable(I))

    # If the *chunk_shape* does not evenly divide the *src_shape*, 
    # *fringe_behaviour* will be used to determine what `RegionIterator` does
    # with the partial chunks at the boundary. See `RegionIterator::FringeBehaviour`
    # for options and documentation.
    @fringe_behaviour : FringeBehaviour

    # The degeneracy array that is internally uesd when constructing the `IndexRegion`.
    # See `IndexRegion` for more information.
    @degeneracy : Array(Bool)

    def_clone
    delegate :reset, to: @coord_iter

    protected def initialize(@src_shape : Indexable(I), @chunk_shape, @coord_iter : Iterator(Indexable(I)), degeneracy : Array(Bool)? = nil, @fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      @degeneracy = degeneracy || Array.new(@src_shape.size, false)
    end

    # TODO: iter inputs, etc
    def self.new(src_shape : Shape(I), chunk_shape : Shape(I), strides : Coord? = nil, degeneracy = nil,
                 fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD, &block : IndexRegion(I) -> Iterator(Indexable(I)))
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

    def self.new(src_shape : Indexable(I), chunk_shape : Shape(I), strides : Coord? = nil, degeneracy = nil,
                 fringe_behaviour : FringeBehaviour = FringeBehaviour::DISCARD)
      new(src_shape, chunk_shape, strides, degeneracy, fringe_behaviour) do |region|
        LexIterator.new(region)
      end
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
      case fringe_behaviour
      in FringeBehaviour::COVER
        src_shape.map_with_index do |size, i|
          if strides[i] < chunk_shape[i]
            strides[i] * complete_chunks(size, strides[i], chunk_shape[i])
          else
            strides[i] * chunks(size, strides[i])
          end
        end
      in FringeBehaviour::ALL_START_POINTS
        src_shape.map_with_index do |size, i|
          strides[i] * chunks(size, strides[i])
        end
      in FringeBehaviour::DISCARD
        src_shape.map_with_index do |size, i|
          strides[i] * complete_chunks(size, strides[i], chunk_shape[i])
        end
      end
    end

    protected def compute_region(coord : Coord)
      region = IndexRegion.cover(@chunk_shape, drop: true, degeneracy: @degeneracy.clone)
      region.translate!(coord)

      unless @fringe_behaviour == FringeBehaviour::DISCARD
        region.trim!(@src_shape)
      end

      region
    end

    def next
      coord = @coord_iter.next
      case coord
      when Stop
        stop
      else
        compute_region(coord)
      end
    end

    def unsafe_next
      compute_region(@coord_iter.unsafe_next)
    end

    # TODO: This is actualy really hard to document without images
    enum FringeBehaviour
      DISCARD
      COVER
      ALL_START_POINTS
    end
  end
end
