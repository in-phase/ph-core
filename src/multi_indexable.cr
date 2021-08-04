module Phase
  # Assumptions:
  # - length along every axis is finite and positive, and each element is positively indexed
  # - size is stored as an Int32, i.e. there are no more than Int32::MAX elements.

  # The `MultiIndexable` module provides a unified interface for multidimensional
  # array types, much like how `Indexable` provides a standard corpus of methods for
  # one-dimensional collections.
  #
  # Implementing `MultiIndexable` will require that you provide a `#shape` and `#unsafe_fetch_element`
  # method, however this is the bare minimum. For a performant implementation, you should consider
  # overriding `#unsafe_fetch_chunk`, `#fast`, and `#size` in that order of importance (and more as you see fit).
  module MultiIndexable(T)
    # provides search, traversal methods
    include Enumerable(T)

    # :nodoc:
    # Dictates whether `Phase` removes (drops) axes that are indexed by an
    # integer literal.  For example, given a 3x3 identity matrix, `mat[0, ..]`
    # will be either the matrix slice `[[1, 0, 0]]` (drop disabled by default)
    # or the vector `[1, 0, 0]` (dropping enabled).  See `IndexRegion#new`
    # (anything accepting `region_literal`) for more information about this
    # behaviour.
    DROP_BY_DEFAULT = true

    # TODO: remove this comment block
    # Please consider overriding:
    # -fast: for performance
    # -transform functions: reshape, permute, reverse; for performance
    # -unsafe_fetch_chunk: for performance and return type (defaults to NArray)
    # -size: if you can precompute size or get it via a buffer size, it's a big performance boost

    # Returns the capacity of each axis spanned by `self`.
    # For example, a matrix with 4 rows and 2 columns will have the shape
    # [4, 2]. This must always return a clone of the actual shape, and is
    # safe to mutate without affecting the MultiIndexable.
    abstract def shape : Array

    # Returns the element at the provided *coord*, without canonicalizing or bounds-checking it.
    # This method cannot be used with negative coordinates, and is not safe
    # unless you are certain your coordinate is already canonicalized.
    abstract def unsafe_fetch_element(coord : Coord) : T

    # By default, this is an alias of `shape` - however, `MultiIndexable` will
    # never mutate it, so it's safe to override this so that it returns a direct
    # reference to a shape variable. Doing so will make most operations faster,
    # because `shape` performs an often useless clone for safety.
    #
    # You do not have to override this method, but unless you have a very strange
    # use case, you almost certainly should.
    protected def shape_internal : Shape
      shape
    end

    # Returns true if both the shape and elements of `self` and *other* are equal.
    #
    # ```crystal
    # NArray.new([1, 2]) == NArray.new([1, 2]) # => true
    # NArray.new([[1], [2]]) == NArray.new([1, 2]) # => false
    # NArray.new([8, 2]) == NArray.new([1, 2]) # => false
    # ```
    def ==(other : self) : Bool
      equals?(other) do |this_elem, other_elem|
        this_elem == other_elem
      end
    end

    # :nodoc:
    def ==(other) : Bool
      false
    end

    # Returns the total number of elements in this `MultiIndexable`.
    # This quantity is always equal to `shape.product`. However, this method is
    # almost always more performant than computing the product directly.
    #
    # ```crystal
    # NArray.new(['a', 'b', 'c']).size # => 3
    # NArray.new([[0, 1], [1, 0]]).size # => 4
    # ```
    def size
      shape_internal.product
    end

    # Returns `true` if and only if this `MultiIndexable` spans no elements.
    #
    # ```crystal
    # NArray.new([1, 2, 3]).empty? # => false
    # NArray.new([]).empty? # => true
    # ```
    def empty? : Bool
      size == 0
    end

    # Returns `true` if this `MultiIndexable` contains only a single element.
    # 
    # ```crystal
    # NArray.new([1]).scalar? # => true
    # NArray.new([1, 2]).scalar? # => false
    # NArray.new([[1]]).scalar? # => true
    # NArray.new([]).scalar? # => false
    # ```
    def scalar? : Bool
      size == 1
    end

    # If this `MultiIndexable` is a scalar (see `#scalar?`), `to_scalar` will
    # return the sole element that it contains. This method will raise a
    # `ShapeError` if `self.scalar?` returns `false`.
    #
    # ```crystal
    # NArray.new(['a']).to_scalar # => 'a'
    # NArray.new([['a', 'b'], ['c', 'd']]).to_scalar # raises ShapeError
    # ```
    def to_scalar : T
      if scalar?
        first
      else
        raise ShapeError.new("Only single-element MultiIndexables can be converted to scalars, but this one has #{size} elements (shape: #{shape_internal}).")
      end
    end

    # Identical to `#to_scalar`, but returns `nil` in case of an error.
    #
    # ```crystal
    # NArray.new(['a']).to_scalar # => 'a'
    # NArray.new([['a', 'b'], ['c', 'd']]).to_scalar # => nil
    # ```
    def to_scalar? : T?
      return first if scalar?
      false
    end

    # Returns `to_scalar.to_f`.
    # This method allows single-element MultiIndexables to be treated like
    # numerics in many cases.
    #
    # ```crystal
    # NArray.new([[0.5f32]]).to_f # => 0.5
    # NArray.new([[1], [2]]).to_f # raises ShapeError
    # NArray.new(["test"]).to_f # will not compile, as String has no #to_f method.
    # ```
    def to_f : Float
      to_scalar.to_f
    end

    # Returns the element at the zero coordinate (position `0` along every axis).
    # For example:
    #
    # ```crystal
    # # create the following matrix:
    # # [5 2]
    # # [8 3]
    # narr = NArray.new([[5, 2], [8, 3]])
    # 
    # # extract the top-left element (coordinate [0, 0])
    # narr.first # => 5
    # ```
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

    # Checks that the `IndexRegion` *region* is in-bounds for this `{{@type}}`.
    def has_region?(region : IndexRegion) : Bool
      region.fits_in?(shape_internal)
    end

    # Checks that *region* is in-bounds for this `{{@type}}`.
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
        unsafe_fetch_element(region.local_to_absolute_unsafe(coord))
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
      unsafe_fetch_chunk(region.trim!(shape_internal))
    end

    def get_available(region : Indexable, drop : Bool = DROP_BY_DEFAULT)
      unsafe_fetch_chunk(IndexRegion.new(region, shape_internal, drop, trim_to: shape))
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
    def []?(region : Indexable | IndexRegion, drop : Bool = MultiIndexable::DROP_BY_DEFAULT) : MultiIndexable(T)?
      if has_region?(region)
        return get_chunk(region)
      end
      nil
    end

    # Retrieves the element specified by `coord`, and throws an error if `coord` is out-of-bounds for this `{{@type}}`.
    def get_element(coord : Indexable) : T
      unsafe_fetch_element CoordUtil.canonicalize_coord(coord, shape_internal)
    end

    def get(coord : Indexable) : T
      get_element(coord)
    end

    {% begin %}
      {% functions_with_drop = %w(get_chunk get_available [] []?) %}
      {% for name in functions_with_drop %}
          # Tuple-accepting overload of `#{{name.id}}`.
          def {{name.id}}(*tuple, drop : Bool = MultiIndexable::DROP_BY_DEFAULT)
            self.{{name.id}}(tuple, drop)
          end
      {% end %}

      {% functions_without_drop = %w(get get_element has_coord? has_region?) %}
      {% for name in functions_without_drop %}
          # Tuple-accepting overload of `#{{name.id}}`.
          def {{name.id}}(*tuple)
            self.{{name.id}}(tuple)
          end
      {% end %}
    {% end %}

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

    def each_slice(axis = 0, &block)
      each_slice(axis).each do |slice|
        yield slice
      end
    end

    def slices(axis = 0) : Enumerable
      each_slice(axis).to_a
    end

    {% for name in %w(each each_coord each_with_coord fast) %}
      # Block accepting form of `#{{name.id}}`.
      def {{name.id}}(&block) : Nil
        {{name.id}}.each {|arg| yield arg}
      end
    {% end %}

    {% for transform in %w(reshape permute reverse) %}
      def {{transform.id}}(*args) : MultiIndexable(T)
        view.{{transform.id}}(*args).to_narr
      end
    {% end %}

    def tile(counts : Enumerable) : MultiIndexable
      NArray.tile(self, counts)
    end

    def to_narr : NArray(T)
      NArray.build(@shape.dup) do |coord, _|
        unsafe_fetch_element(coord)
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
        hasher = el.hash(hasher)
      end
      hasher
    end

    # TODO: These macro-generated methods are currently nodoc because there are so many.
    # we need to figure out a way to document these without spamming :p
    {% begin %}
      # Implements most binary operations
      {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^ <=>) %}

        # :nodoc:
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

        # :nodoc:
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
