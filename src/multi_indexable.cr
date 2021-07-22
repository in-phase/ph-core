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

    # Returns the number of elements in the `{{@type}}`; equal to `shape.product`.
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

    # Checks that the `{{@type}}` contains no elements.
    def empty? : Bool
      size == 0
    end

    # Checks that this `{{@type}}` is one-dimensional, and contains a single element.
    def scalar? : Bool
      size == 1
    end

    # Maps a single-element 1D `{{@type}}` to the element it contains.
    def to_scalar : T
      if scalar?
        first
      else
        raise ShapeError.new("Only single-element MultiIndexables can be converted to scalars, but this one has #{size} elements (shape: #{shape_internal}).")
      end
    end

    def to_scalar? : T?
      return first if scalar?
      false
    end

    def to_f : Float 
      to_scalar.to_f
    end

    # Returns the element at position `0` along every axis.
    def first : T
      if size == 0
        raise IndexError.new("{{@type}} has zero elements (shape: #{shape_internal}).")
      end

      get_element(Array.new(shape_internal.size, 0))
    end

    # Returns a random element from the `{{@type}}`. Note that this might not return
    # distinct elements if the random number generator returns the same coordinate twice.
    def sample(n : Int, random = Random::DEFAULT) : Enumerable(T)
      if n < 0
        raise ArgumentError.new("Can't sample a negative number of elements. (n = #{n}, which is negative)")
      end

      Array(T).new(n) { sample(random) }
    end

    # Returns a random element from the `{{@type}}`.
    def sample(random = Random::DEFAULT) : T
      raise ShapeError.new("Can't sample empty collection. (shape: #{shape_internal})") if empty?
      unsafe_fetch_element(shape_internal.map { |dim| random.rand(dim) })
    end

    # Returns the number of indices required to specify an element in `{{@type}}`.
    def dimensions : Int
      shape_internal.size
    end

    # Checks that `coord` is in-bounds for this `{{@type}}`.
    def has_coord?(coord : Indexable) : Bool
      CoordUtil.has_coord?(coord, shape_internal)
    end

    # Checks that `region` is in-bounds for this `{{@type}}`.
    def has_region?(region : Indexable) : Bool
      IndexRegion.new(region, shape_internal)
      true
    rescue ex : IndexError
      false
    end

    # Copies the elements in `region` to a new `{{@type}}`, assuming that `region` is in canonical form and in-bounds for this `{{@type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_fetch_chunk(region : IndexRegion)
      NArray.build(region.shape) do |coord|
        unsafe_fetch_element(region.local_to_absolute(coord))
      end
    end

    # Copies the elements in `region` to a new `{{@type}}`, and throws an error if `region` is out-of-bounds for this `{{@type}}`.
    def get_chunk(region : IndexRegion) : MultiIndexable(T)
      # TODO: Write good error messages
      raise DimensionError.new if region.proper_dimensions != dimensions
      raise ShapeError.new unless region.fits_in?(shape_internal)
      unsafe_fetch_chunk(region)
    end

    # Copies the elements in `region` to a new `{{@type}}`, and throws an error if `region` is out-of-bounds for this `{{@type}}`.
    def get_chunk(region : Indexable, drop : Bool = DROP_BY_DEFAULT)
      unsafe_fetch_chunk IndexRegion.new(region, shape_internal, drop)
    end

    # "drags out" a region of shape region_shape with coord as the top left corner
    def get_chunk(coord : Indexable, region_shape : Indexable)
      get_chunk(IndexRegion.new(region_shape).translate!(coord))
    end

    def get_available(region : IndexRegion, drop : Bool = DROP_BY_DEFAULT)
      unsafe_get_chunk(region.trim!(shape_internal))
    end

    def get_available(region : Indexable, drop : Bool = DROP_BY_DEFAULT)
      unsafe_get_chunk(IndexRegion.new(region, shape_internal, drop, trim_to: shape))
    end

    def [](bool_mask : MultiIndexable(Bool)) : self
      self
    end

    def []?(bool_mask : MultiIndexable(Bool)) : MultiIndexable(T?)
      if bool_mask.shape != shape_internal
        raise ShapeError.new("Could not use mask: mask shape #{bool_mask.shape} does not match this MultiIndexable's shape (#{shape_internal}).")
      end

      bool_mask.map_with_coord do |bool_val, coord|
        bool_val ? unsafe_fetch_element(coord) : nil
      end
    end

    # Copies the elements in `region` to a new `{{@type}}`, and throws an error if `region` is out-of-bounds for this `{{@type}}`.
    def [](region : Indexable | IndexRegion, drop : Bool = MultiIndexable::DROP_BY_DEFAULT)
      get_chunk(region)
    end

    # Copies the elements in `region` to a new `{{@type}}`, or returns false if `region` is out-of-bounds for this `{{@type}}`.
    def []?(region : Indexable | IndexRegion, drop : Bool = MultiIndexable::DROP_BY_DEFAULT) : self?
      if has_region?(region)
        get_chunk(region)
      end
      false
    end

    # Retrieves the element specified by `coord`, and throws an error if `coord` is out-of-bounds for this `{{@type}}`.
    def get_element(coord : Indexable) : T
      unsafe_fetch_element CoordUtil.canonicalize_coord(coord, shape_internal)
    end

    def get(coord : Indexable) : T
      get_element(coord)
    end

    {% begin %}
      {% functions_with_drop = %w(get_chunk [] []?) %}
      {% for name in functions_with_drop %}
          # Tuple-accepting overload of `#{{name}}`.
          def {{name.id}}(*tuple, drop : Bool = MultiIndexable::DROP_BY_DEFAULT)
            self.{{name.id}}(tuple, drop)
          end
      {% end %}

      {% functions_without_drop = %w(get get_element has_coord? has_region?) %}
      {% for name in functions_without_drop %}
          # Tuple-accepting overload of `#{{name}}`.
          def {{name.id}}(*tuple)
            self.{{name.id}}(tuple)
          end
      {% end %}
    {% end %}

    # Iterators ====================================================================
    def each_coord : Iterator #(Coord)
      LexIterator.cover(shape)
    end

    # The default iterator must be lexicographic
    def each : Iterator(T)
      each(each_coord)
    end

    def each(iter : CoordIterator(I)) : Iterator(T) forall I
      ElemIterator.of(self, iter)
    end

    def each_with_coord : Iterator # Iterator(Tuple(T, Coord)) # "Error: can't use Indexable(T) as a generic type argument yet"
      each_with_coord(each_coord)
    end

    def each_with_coord(iter : CoordIterator(I)) : Iterator forall I # Iterator(Tuple(T, Coord))
      ElemAndCoordIterator.of(self, iter)
    end

    def map_with_coord(&block) # : (T, U -> R)) : MultiIndexable(R) forall R,U
      NArray.build(shape_internal) do |coord, i|
        yield unsafe_fetch_element(coord), coord
      end
    end

    # By default, gives an NArray
    def map(&block : (T -> R)) : MultiIndexable(R) forall R
      map_with_coord do |el, coord|
        yield el
      end
    end

    # A method to get all elements in this `{{@type}}` when order is irrelevant.
    # Recommended that implementers override this method to take advantage of
    # the storage scheme the implementation uses
    def fast : Iterator(T)
      ElemIterator.of(self)
    end

    # # TODO: Each methods should exist that allow:
    # # - Some way to handle slice iteration? (how do we pass in the axis? etc)

    def each_slice(axis = 0) : Iterator
      chunk_shape = shape
      chunk_shape[axis] = 1
      degeneracy = Array.new(dimensions, false)
      degeneracy[axis] = true
      ChunkIterator.new(self, chunk_shape, degeneracy: degeneracy)
    end

    def slices(axis = 0) : Enumerable
      each_slice.to_a
    end

    {% for name in %w(each each_coord each_with_coord each_slice fast) %}
      # Block accepting form of {{name}}.
      def {{name.id}}(&block) : Nil
        {{name.id}}.each {|arg| yield arg}
      end
    {% end %}

    {% for transform in %w(reshape permute reverse) %}
      def {{transform.id}}(*args) : MultiIndexable(T)
        view.{{transform.id}}(*args).to_narr
      end
    {% end %}

    def to_narr : NArray(T)
      NArray.build(@shape.dup) do |coord, _|
        unsafe_fetch_element(coord)
      end
    end

    def equals?(other : MultiIndexable) : Bool
      equals?(other) do |this_elem, other_elem|
        this_elem == other_elem
      end
    end

    def equals?(other : MultiIndexable, &block) : Bool
      return false if shape_internal != other.shape_internal
      each_with_coord do |elem, coord|
        return false unless yield(elem, other.unsafe_fetch_element(coord))
      end
      true
    end

    def view(region : Indexable? | IndexRegion = nil) : View(self, T)
      # TODO: Try to infer T from B?
      View.of(self, region)
    end

    def view(*region) : View(self, T)
      view(region)
    end

    def process(&block : (T -> R)) : ProcView(self, T, R) forall R
      process(block)
    end

    def process(proc : Proc(T, R)) : ProcView(self, T, R) forall R
      ProcView.of(self, proc)
    end

    # TODO: rename!
    # Produces an NArray(Bool) (by default) describing which elements of self and other are equal.
    def eq(other : MultiIndexable(U)) : MultiIndexable(Bool) forall U
      if shape_internal != other.shape_internal
        raise DimensionError.new("Cannot compute the element-wise equality between this MultiIndexable (shape: #{shape_internal}) and the one provided (shape: #{other.shape_internal}).")
      end

      map_with_coord do |elem, coord|
        elem == other.unsafe_fetch_element(coord)
      end
    end

    def eq(value) : MultiIndexable(Bool)
      map do |elem|
        elem == value
      end
    end

    def hash(hasher)
      hasher = shape_internal.hash(hasher)
      each do |el|
        hasher = elem.hash(hasher)
      end
      hasher
    end

    {% begin %}
      # Implements most binary operations
      {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^ <=>) %}

        # Invokes `#{{name.id}}` element-wise between `self` and *other*, returning
        # an `NArray` that contains the results.
        def {{name.id}}(other : MultiIndexable(U)) forall U 
          if shape_internal != other.shape_internal
            if scalar? || other.scalar?
              raise DimensionError.new("The shape of this MultiIndexable (#{shape_internal}) does not match the shape of the one provided (#{other.shape_internal}), so '{{name.id}}' cannot be applied element-wise. Did you mean to call to_scalar on one of the arguments?")
            end
            raise DimensionError.new("The shape of this MultiIndexable (#{shape_internal}) does not match the shape of the one provided (#{other.shape_internal}), so '{{name.id}}' cannot be applied element-wise.")
          end

          map_with_coord do |elem, coord|
            elem.{{name.id}} other.unsafe_fetch_element(coord)
          end
        end

        # Invokes `#{{name.id}}(other)` on each element in `self`, returning an
        # `NArray` that contains the results.
        def {{name.id}}(other)
          map &.{{name.id}} other
        end
      {% end %}

      {% for name in %w(- + ~) %}
        def {{name.id}}
          map &.{{name.id}} 
        end
      {% end %}
    {% end %}
  end
end
