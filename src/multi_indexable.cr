module Phase
  # Assumptions:
  # - length along every axis is finite and positive, and each element is positively indexed
  # - size is stored as an Int32, i.e. there are no more than Int32::MAX elements.
  module MultiIndexable(T)
    # add search, traversal methods
    include Enumerable(T)

    DROP_BY_DEFAULT = true

    # Please consider overriding:
    # -fast: for performance
    # -transform functions: reshape, permute, reverse; for performance
    # -unsafe_fetch_chunk: for performance and return type (defaults to NArray)

    # Returns the number of elements in the `{{@type}}`; generally equal to `shape.product`.
    abstract def size

    # Returns the length of the `{{@type}}` in each dimension.
    # For a `coord` to specify an element of the `{{@type}}` it must satisfy `coord[i] < shape[i]` for each `i`.
    abstract def shape : Array

    # Retrieves the element specified by `coord`, assuming that `coord` is in canonical form and in-bounds for this `{{@type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    abstract def unsafe_fetch_element(coord : Coord) : T

    # Stuff that we can implement without knowledge of internals

    protected def shape_internal : Shape
      # NOTE: Some implementations might not have a well defined @shape, but
      # instead generate it with a function. We leave shape_internal to be
      # overridden with @shape for a small performance boost if the implementer
      # offers that.
      shape
    end

    def empty?
      size == 0
    end

    def size
      puts "using mine" 
      shape_internal.product
    end

    def sample(random = Random::DEFAULT) : T
      raise ShapeError.new("Can't sample empty collection. (shape: #{shape_internal})") if empty?
      unsafe_fetch_element(shape_internal.map { |dim| random.rand(dim) })
    end

    # Returns the number of indices required to specify an element in `{{@type}}`.
    def dimensions : Int
      shape_internal.size
    end

    # Iterators ====================================================================
    def each_coord : Iterator # (Coord)
      LexIterator.cover(shape)
    end

    # The default iterator must be lexicographic
    def each : Iterator(T)
      each(each_coord)
    end

    def each(iter : CoordIterator(I)) : Iterator(T) forall I
      ElemIterator.of(self, iter)
    end

    {% for name in %w(each) %}
      # Block accepting form of {{name}}.
      def {{name.id}}(&block) : Nil
        {{name.id}}.each {|arg| yield arg}
      end
    {% end %}

    def to_narr : NArray(T)
      NArray.build(@shape.dup) do |coord, _|
        unsafe_fetch_element(coord)
      end
    end
  end
end
