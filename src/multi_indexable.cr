module Phase
  # Assumptions:
  # - length along every axis is finite and positive, and each element is positively indexed
  # - size is stored as an Int32, i.e. there are no more than Int32::MAX elements.

  # The `MultiIndexable` module provides a unified interface for
  # multidimensional array types, much like how `Indexable` provides a standard
  # corpus of methods for one-dimensional collections.
  #
  # ### How to Implement a `MultiIndexable`
  # Implementing `MultiIndexable` will require that you provide a `#shape` and
  # `#unsafe_fetch_element` method, however this is the bare minimum. For a
  # performant implementation, you should consider overriding
  # `#unsafe_fetch_chunk`, `#fast`, and `#size` in that order of importance
  # (and more as you see fit).
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
    # Returns `false` for any *other* that is not the same type as `self`
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

    # Returns a random element from the `{{@type}}`. Note that this might not
    # return distinct elements if the random number generator returns the same
    # coordinate twice.

    # Returns a collection of *n* elements picked at random from this
    # MultiIndexable.  This method works by randomly generating coordinates and
    # returning the elements at those coordinates. There is no guarantee that
    # the coordinates generated will be distinct from one another.
    #
    # ```crystal
    # NArray.new([[1, 2], [3, 4]]).sample(5) # => Enumerable(Int32)
    # NArray.new([[1, 2], [3, 4]]).sample(5).to_a # => [4, 2, 4, 3, 2]
    # NArray.new([[1, 2], [3, 4]]).sample(5).to_a # => [1, 3, 2, 4, 1]
    # NArray.new([[1, 2], [3, 4]]).sample(5).to_a # => [2, 3, 1, 1, 3]
    # ```
    def sample(n : Int, random = Random::DEFAULT) : Enumerable(T)
      if n < 0
        raise ArgumentError.new("Can't sample a negative number of elements. (n = #{n}, which is negative)")
      end

      Array(T).new(n) { sample(random) }
    end

    # Returns an element picked at random from this `MultiIndexable`.
    #
    # ```crystal
    # NArray.new([[1, 2], [3, 4]]).sample # => 3
    # NArray.new([[1, 2], [3, 4]]).sample # => 1
    # NArray.new([[1, 2], [3, 4]]).sample # => 2
    # ```
    def sample(random = Random::DEFAULT) : T
      raise ShapeError.new("Can't sample empty collection. (shape: #{shape_internal})") if empty?
      unsafe_fetch_element(shape_internal.map { |dim| random.rand(dim) })
    end

    # Returns the number of dimensions that this MultiIndexable is embedded in.
    # This can equally be seen by the number of indices required to uniquely
    # specify a coordinate into this `MultiIndexable`, and is always equal to
    # `shape.size`
    #
    # ```crystal
    # NArray.new([1, 2]).dimensions # => 1
    # NArray.new([[1, 2], [3, 4]]).dimensions # => 2
    # NArray.new([[[1]]]).dimensions # => 3
    # ```
    def dimensions : Int
      shape_internal.size
    end

    # Returns true if *coord* is a valid coordinate in this `MultiIndexable`.
    # Any coordinate for which `#has_coord?` returns `true` can be used in
    # `#get`. A coordinate for which `#has_coord?` returns `false` is out of
    # bounds.
    #
    # ```crystal
    # # creates the following matrix:
    # # [1 2 3]
    # # [4 5 6]
    # narr = NArray.build([2, 3]) { |_, idx| idx + 1 }
    #
    # narr.has_coord?([0, 0]) # => true
    # narr.get([0, 0]) # => 1
    #
    # narr.has_coord?([-2, 1]) # => true
    # narr.get(-2, 1) # => 2
    #
    # narr.has_coord?([-2]) # => true
    # narr.get(-2) # => DimensionError
    # ```
    def has_coord?(coord : Indexable) : Bool
      CoordUtil.has_coord?(coord, shape_internal)
    end

    # IndexRegion accepting form of `#has_region?(region_literal)`
    def has_region?(region : IndexRegion) : Bool
      region.fits_in?(shape_internal)
    end

    # Returns true if all the coordinates spanned by *region_literal* are valid coordiantes in this `MultiIndexable`.
    # In a more geometric sense, an `IndexRegion` can be considered as a lattice
    # of points (coordinates), and `#shape` can be considered as a bounding box
    # for those coordinates. If every coordinate within *region* (each point
    # on that lattice) is inside of the bounding box, then `#has_region` will
    # return true.
    #
    # ```crystal
    # narr = NArray.build([10, 3]) { |_, idx| idx }
    # 
    # # First, we'll make an IndexRegion that fits in the above. This IndexRegion
    # # contains all coordinates with a row equal to 2, 3, or 4, and a column
    # # equal to 0, 1, or 2.
    # valid = [2..4, 0...3]
    # 
    # # narr has 10 rows and 3 columns, so that region is definitely
    # # contained in it.
    # narr.has_region?(valid) # => true
    # 
    # # now, we can use that IndexRegion safely.
    # LexIterator(Int32).new(valid).each do |coord|
    #   narr.unsafe_fetch_element(coord) # this is definitely defined!
    # end
    # 
    # # Now we'll create an IndexRegion that's way too big for narr:
    # invalid = [100, 2..8]
    # narr.has_region?(invalid) # => false
    # 
    # # The region doesn't fit - so:
    # narr.get_chunk(invalid) # => raises an IndexError
    # ```
    def has_region?(region_literal : Indexable) : Bool
      IndexRegion.new(region_literal, shape_internal)
      true
    rescue ex : IndexError
      false
    end

    # Copies the elements described by *region* into a new `MultiIndexable` without performing any bounds checking.
    # Unless you are sure that your *region* will fit inside of this
    # `MultiIndexable`, you should opt to use `#get_chunk` instead.
    #
    # This method may return any `MultiIndexable` - the default implementation
    # will return an `NArray`, however implementers of other `MultiIndexable`s
    # are encouraged to override this method where it makes sense to do so.
    #
    # This method's usage is identical to `#get_chunk(region : IndexRegion)`,
    # but it is slightly faster.
    def unsafe_fetch_chunk(region : IndexRegion) : MultiIndexable(T)
      NArray.build(region.shape) do |coord|
        unsafe_fetch_element(region.local_to_absolute_unsafe(coord))
      end
    end

    # `IndexRegion` accepting form of `#get_chunk(region_literal : Indexable, drop : Bool)`.
    # Note that *region* is what controls the dimension dropping behaviour, here.
    def get_chunk(region : IndexRegion) : MultiIndexable(T)
      # TODO: Write good error messages
      if region.proper_dimensions != dimensions
        raise DimensionError.new("'region' was #{region.proper_dimensions}-dimensional, but this MultiIndexable is #{dimensions}-dimensional.")
      end

      unless region.fits_in?(shape_internal)
        raise ShapeError.new("'region' (#{region}) cannot fit into a MultiIndexable with shape #{shape}.")
      end

      unsafe_fetch_chunk(region)
    end

    # A more verbose overload of `#[](region_literal : Indexable, drop : Bool)`.
    # This is just syntactic sugar, and can be more readable in certain
    # applications.
    def get_chunk(region_literal : Indexable, drop : Bool = DROP_BY_DEFAULT)
      unsafe_fetch_chunk IndexRegion.new(region_literal, shape_internal, drop)
    end

    # Extracts a chunk given a shape (*region_shape*) and the *coord* in that region with the smallest value in each axis.
    #
    # ```crystal
    # narr = NArray.new([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    # 
    # narr.get_chunk([1, 1], [2, 2]) # => NArray[[5, 6], [8, 9]]
    # narr.get_chunk([1, 0], [1, 3]) # => NArray[[4, 5, 6]]
    # narr.get_chunk([1, 0], [10, 10]) # => ShapeError
    # narr.get_chunk([0], [1]) # => DimensionError
    # ```
    def get_chunk(coord : Indexable, region_shape : Indexable(I)) forall I
      if coord.size != region_shape.size
        raise DimensionError.new("'coord' (#{coord}) and 'region_shape' #{region_shape} had a different number of dimensions. Note that you must fully specify your coordinate and region shape for this overload of get_chunk.")
      end

      if coord.size != dimensions
        raise DimensionError.new("'coord' (#{coord}) had a different number of dimensions than this MultiIndexable (must have #{dimensions}, but has #{coord.size}).")
      end

      coord.each_with_index do |c, idx|
        r = region_shape.unsafe_fetch(idx)
        if c.negative?
          raise ArgumentError.new("'coord' #{coord} was negative on axis #{idx}, but must be strictly nonnegative.")
        end

        if r.negative?
          raise ArgumentError.new("'region_shape' #{region_shape} was negative on axis #{idx}, but must be strictly nonnegative.")
        end

        if c + r > shape_internal.unsafe_fetch(idx)
          raise ShapeError.new("The region defined by shape #{region_shape} and lowermost coordinate #{coord} is not contained within this MultiIndexable on axis #{idx} (this MultiIndexable has #{shape_internal[idx]} elements on axis #{idx}).")
        end
      end

      get_chunk(IndexRegion(I).cover(region_shape).translate!(coord))
    end

    # `IndexRegion` accepting overload of `get_available(region : Indexable, drop : Bool)`
    def get_available(region : IndexRegion, drop : Bool = DROP_BY_DEFAULT)
      unsafe_fetch_chunk(region.trim!(shape_internal))
    end

    # Returns a `MultiIndexable` containing elements whose coordinates belong both to `shape` and *region_literal*.
    # This method is very similar to `get_chunk(region_literal : Indexable, drop : Bool)`,
    # except that it trims the *region_literal* down to a valid size automatically.
    #
    # ```crystal
    # narr = NArray.new([[1, 2, 3], [4, 5, 6]])
    # 
    # narr.get_chunk(1..5, 1) # => ShapeError (this chunk is not contained in a 2x3 MultiIndexable
    # narr.get_available(1..5, 1) # => NArray[5]
    # ```
    def get_available(region_literal : Indexable, drop : Bool = DROP_BY_DEFAULT)
      unsafe_fetch_chunk(IndexRegion.new(region_literal, shape_internal, drop, trim_to: shape_internal))
    end

    # :nodoc:
    # This method allows operations of the form `narr[mask] += 5` - it's listed here to minimize confusion, but you should never use it.
    #
    # In Crystal, expressions of the form `#{op}=` are not actually overridable
    # functions - instead, the complier expands them as such:
    #
    # ```crystal
    # a += b # => expands to a = a + b
    # ```
    #
    # In Phase, this is generally fine, as all meaningful operators have been implemented:
    # ```crystal
    # narr += 1 # => narr = narr + 1
    # ```
    #
    # However, when boolean masks are involved, this syntax is problematic.
    # Consider the following example, which does not involve much complication:
    # ```crystal
    # narr = NArray[3, 4, 5]
    # mask = NArray[false, true, true]
    # narr[mask] = 1
    # puts narr # => NArray[3, 1, 1] (every location where mask was true got assigned, but other locations were not changed)
    # ```
    #
    # And now the final example, which shows the issue:
    # ```crystal
    # narr = NArray[3, 4, 5]
    # mask = NArray[false, true, true]
    # narr[mask] += 1
    # ```
    #
    # It is perfectly clear what `narr` ought to be, now - the spots where the mask
    # is true should get one added to them. But look at what the compiler expands that
    # last line to:
    #
    # ```crystal
    # narr[mask] += 1 # => narr[mask] = narr[mask] + 1
    # ```
    #
    # So, we have a problem - until now, `NArray` only needed to implement the setter
    # `MultiWritable#[]=(bool_mask : MultiIndexable(Bool), value)` - but now,
    # it must also implement the getter `#[](bool_mask : MultiIndexable(Bool))`.
    #
    # Because `#[](bool_mask)` does not have a particularly meaningful definition,
    # we opted to simply make it return `self`, which allows our problematic
    # example to work:
    #
    # ```crystal
    # narr[mask] += 1
    #   # Crystal expands this to:
    #   # narr[mask] = narr[mask] + 1
    #   # MultiIndexable#[](bool_mask) just returns self:
    #   # narr[mask] = self + 1
    # ```
    #
    # As you can see, this fixes the problem. However, it is not very efficient,
    # because it creates a full copy of `self` and adds one to every element.
    #
    # To recap - this method is only used internally, and you should never need
    # to use it explicitly.
    #
    # TODO: Try to optimize this use case, possibly with a ProcView over self
    # instead of self
    def [](bool_mask : MultiIndexable(Bool)) : self
      self
    end

    # Returns a `MultiIndexable` that draws from `self` where *bool_mask* is true, but contains `nil` where *bool_mask* is false.
    # If *bool_mask* has a different shape than `self`, this method will raise
    # a `ShapeError`.
    #
    #
    # ```crystal
    # narr = NArray[3, 4, 5]
    # mask = NArray[false, true, true]
    # narr[mask]? # => NArray[nil, 4, 5]
    # 
    # oversized_mask = NArray[false, true, true, false]
    # narr[oversized_mask]? # => ShapeError
    # ```
    def []?(bool_mask : MultiIndexable(Bool)) : MultiIndexable(T?)
      if bool_mask.shape != shape_internal
        raise ShapeError.new("Could not use mask: mask shape #{bool_mask.shape} does not match this MultiIndexable's shape (#{shape_internal}).")
      end

      bool_mask.map_with_coord do |bool_val, coord|
        bool_val ? unsafe_fetch_element(coord) : nil
      end
    end

    # Copies the elements described by *region* into a new `MultiIndexable`.
    # If *region* does not describe a valid region of this `MultiIndexable`,
    # this method will raise either a `DimensionError` (in the case of
    # an improper number of dimensions) or a `ShapeError` (in the case where
    # the number of dimensions is correct, but the region is not meaningful
    # for this MultiIndexable's shape.
    #
    # Note: this method has a tuple accepting overload, as well, which makes
    # the syntax much more intuitive. The following example contains both
    # versions, but please note the difference.
    #
    # ```crystal
    # narr = NArray.new([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    # 
    # # Select only the first row:
    # narr[[0], drop: true] # => NArray[1, 2, 3]
    #
    # # Unless you need to explicitly disable dropping, use the tuple overload:
    # narr[0] # => NArray[1, 2, 3] (drop is true by default)
    # 
    # # Select only the first column:
    # narr[.., 0] # => NArray[1, 2, 3]
    # 
    # # Select only the first column, without dropping dimensions:
    # # (in this case, we can't use the tuple accepting overload, hence the extra brackets)
    # narr[[.., 0], drop: false] # => NArray[[1], [2], [3]]
    # 
    # # Equivalently to the above, using anything other than an integer will bypass
    # # dropping:
    # narr[.., 0..0] # => NArray[[1], [2], [3]]
    # 
    # # Select only elements from both even-numbered rows and columns:
    # narr[0..2.., 0..2..] # => NArray[[1, 3], [7, 9]]
    #
    # # This method raises a DimensionError when there is a dimensions mismatch:
    # narr[0, 1, 2, 3] # => DimensionError
    #
    # # This method raises a ShapeError when there is a shape mismatch:
    # narr[1..100, 2..30] # => ShapeError
    # ```
    def [](region_literal : Indexable, drop : Bool = MultiIndexable::DROP_BY_DEFAULT)
      get_chunk(region_literal, drop)
    end

    # `IndexRegion` accepting form of `#[](region_literal : Indexable, drop : Bool)`.
    # Note that *region* is what controls the dimension dropping behaviour, here.
    def [](region : IndexRegion)
      get_chunk(region)
    end

    # Copies the elements in *region* to a new `MultiIndexable` if `#has_region?(region)` is true, and returns `nil` otherwise.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # narr[1.., 10..12]? # => nil
    # narr[0.., 1..2]? # => NArray[[2, 3], [5, 6]]
    # ```
    def []?(region : Indexable, drop : Bool = MultiIndexable::DROP_BY_DEFAULT) : MultiIndexable(T)?
      if has_region?(region)
        return get_chunk(region, drop)
      end

      nil
    end

    # `IndexRegion` accepting overload of `#[]?(region : Indexable, drop : Bool)`.
    def []?(region : IndexRegion) : MultiIndexable(T)?
      if has_region?(region)
        return get_chunk(region)
      end

      nil
    end

    # Retrieves the element specified by *coord*, throwing an error if *coord* is out-of-bounds for `self`.
    #
    #
    # ```crystal
    # narr = NArray[['a', 'b'], ['c', 'd']]
    # narr.get_element([0, 1]) # => 'b'
    # narr.get_element([1, 0]) # => 'c'
    # narr.get_element([0]) # => DimensionError
    # narr.get_element([0, 10]) # => IndexError
    # ```
    def get_element(coord : Indexable) : T
      unsafe_fetch_element CoordUtil.canonicalize_coord(coord, shape_internal)
    end

    # Shorthand for `#get_element`.
    # :ditto:
    def get(coord : Indexable) : T
      get_element(coord)
    end

    {% begin %}
      {% functions_with_drop = %w(get_chunk get_available [] []?) %}
      {% for name in functions_with_drop %}
          # Tuple-accepting overload of `#{{name.id}}(region_literal : Indexable, drop : Bool)`.
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

    # Returns an iterator that will yield each coordinate of `self` in lexicographic (row-major) order.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # iter = narr.each_coord
    # iter.next # => [0, 0]
    # iter.next # => [0, 1]
    # iter.next # => [0, 2]
    # iter.next # => [1, 0]
    # iter.next # => [1, 1]
    # iter.next # => [1, 2]
    # iter.next # => Iterator::Stop
    # ```
    def each_coord : Iterator
      LexIterator.cover(shape)
    end

    # Returns an iterator that will yield each element of `self` in lexicographic (row-major) order.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # iter = narr.each
    # iter.next # => 1
    # iter.next # => 2
    # iter.next # => 3
    # iter.next # => 4
    # iter.next # => 5
    # iter.next # => 6
    # iter.next # => Iterator::Stop
    # ```
    def each : Iterator(T)
      each(each_coord)
    end

    # An overload of `#each` that allows you to provide a coordinate iterator in place of the default lexicographic iterator.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # coord_iter = ColexIterator.cover(narr.shape).reverse!
    # iter = narr.each(coord_iter)
    # iter.next # => 6
    # iter.next # => 3
    # iter.next # => 5
    # iter.next # => 2
    # iter.next # => 4
    # iter.next # => 1
    # iter.next # => Iterator::Stop
    # ```
    def each(iter : CoordIterator(I)) : Iterator(T) forall I
      ElemIterator.of(self, iter)
    end

    # Returns an iterator that will yield tuples of the elements and coords comprising `self` in lexicographic (row-major) order.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # iter = narr.each_with_coord
    # iter.next # => {1, [0, 0]}
    # iter.next # => {2, [0, 1]}
    # iter.next # => {3, [0, 2]}
    # iter.next # => {4, [1, 0]}
    # iter.next # => {5, [1, 1]}
    # iter.next # => {6, [1, 2]}
    # iter.next # => Iterator::Stop
    # ```
    def each_with_coord : Iterator # Iterator(Tuple(T, Coord)) # "Error: can't use Indexable(T) as a generic type argument yet"
      each_with_coord(each_coord)
    end

    # An overload of `#each_with_coord` that allows you to provide a coordinate iterator in place of the default lexicographic iterator.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # coord_iter = ColexIterator.cover(narr.shape).reverse!
    # iter = narr.each_with_coord(coord_iter)
    # puts iter.next # => {6, [1, 2]}
    # puts iter.next # => {3, [0, 2]}
    # puts iter.next # => {5, [1, 1]}
    # puts iter.next # => {2, [0, 1]}
    # puts iter.next # => {4, [1, 0]}
    # puts iter.next # => {1, [0, 0]}
    # ```
    def each_with_coord(iter : CoordIterator(I)) : Iterator forall I # Iterator(Tuple(T, Coord))
      ElemAndCoordIterator.of(self, iter)
    end

    # Returns a `MultiIndexable` with the results of running the block against each element and coordinate comprising `self`.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # narr.map_with_coord do |el, coord|
    #   el + coord.sum
    # end # => NArray[[1, 3, 5], [5, 7, 9]]
    # ```
    def map_with_coord(&block) # : (T, U -> R)) : MultiIndexable(R) forall R,U
      NArray.build(shape_internal) do |coord, i|
        yield unsafe_fetch_element(coord), coord
      end
    end

    # Returns a `MultiIndexable` with the results of running the block against each element of `self`.
    #
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    # res = narr.map { |el| el.to_s } # => NArray[["1", "2", "3"], ["4", "5", "6"]]
    # ```
    def map(&block : (T -> R)) : MultiIndexable(R) forall R
      map_with_coord do |el, coord|
        yield el
      end
    end

    # Returns an Iterator over the elements in this `MultiIndexable` that will iterate in the fastest order possible.
    # For most implementations, it is very likely that `#each` will be just as fast.
    # However, certain implementations of `MultiIndexable` may have substantial
    # performance differences. As a rule of thumb, this method is only worth using
    # if the `MultiIndexable` you call it on explicitly mentions that you should.
    #
    # ```crystal
    # NArray[1, 2, 3].fast.each do |el|
    #   # ...
    # end
    # ```
    def fast : Iterator(T)
      ElemIterator.of(self)
    end

    # Returns an Iterator equivalent to the method `#each_slice(axis, &block)`.
    def each_slice(axis = 0) : Iterator
      chunk_shape = shape
      chunk_shape[axis] = 1
      degeneracy = Array.new(dimensions, false)
      degeneracy[axis] = true
      ChunkIterator.new(self, chunk_shape, degeneracy: degeneracy)
    end

    # Yields the slices of this `MultiIndexable` along a given *axis* to the provided block.
    # The elements returned in each slice are the ones with a constant index
    # along the specified *axis*.
    # 
    # ```crystal
    # narr = NArray[[1, 2, 3], [4, 5, 6]]
    #
    # #          axis one ->
    # #
    # # axis      0 1 2
    # # zero   0 [1 2 3]
    # #  |     1 [4 5 6]
    # #  v
    #
    # # defaults to axis = 0, so the slices will be the rows.
    # narr.each_slice do |slice|
    #   # in loop 0, slice will be NArray[1, 2, 3], because those elements have coords [0, ...]
    #   # in loop 1, slice will be NArray[4, 5, 6], because those elements have coords [1, ...]
    # end
    #
    # # here we pick axis = 1, so the slices will be the columns.
    # narr.each_slice(axis: 1) do |slice|
    #   # in loop 0, slice will be NArray[1, 4], because those elements have coords [..., 0]
    #   # in loop 1, slice will be NArray[2, 5], because those elements have coords [..., 1]
    #   # in loop 0, slice will be NArray[3, 6], because those elements have coords [..., 2]
    # end
    # ```
    def each_slice(axis = 0, &block)
      each_slice(axis).each do |slice|
        yield slice
      end
    end

    # Returns an Indexable collection of the slices returned by `#each_slice`.
    def slices(axis = 0) : Indexable
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

    # Using `self` as a tile, creates a larger `MultiIndexable` by translating and copying that tile in multiple axes.
    # *counts* specifies how many times to copy the tile in each axis. If it is the wrong
    # size, `#tile` will return a `DimensionError`.
    # TODO: Add code sample, write test for this
    def tile(counts : Enumerable) : MultiIndexable
      NArray.tile(self, counts)
    end

    # Creates an `NArray` duplicate of this `MultiIndexable`.
    #
    # ```crystal
    # not_an_narray.to_narr # => NArray
    # ```
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
              raise ShapeError.new("The shape of this MultiIndexable (#{shape_internal}) does not match the shape of the one provided (#{other.shape_internal}), so '{{name.id}}' cannot be applied element-wise. Did you mean to call to_scalar on one of the arguments?")
            end
            raise ShapeError.new("The shape of this MultiIndexable (#{shape_internal}) does not match the shape of the one provided (#{other.shape_internal}), so '{{name.id}}' cannot be applied element-wise.")
          end

          map_with(other) do |elem, other_elem|
            elem.{{name.id}} other_elem
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

    def each_with(*args, &block)
      MultiIndexable.each_with(self, *args) do |*elems|
        yield *elems
      end
    end

    # def map_with(*args, &block)
    #   map_with(*args, block: block)
    # end

    # def map_with(*args, proc : P) forall P
    #   {% begin %}
    #   buffer = Pointer({{P.type_vars[1]}}).malloc(size)
    #   MultiIndexable.each_with(self, *args) do |*elems|
    #     proc.call(*elems)
    #   end
    #   {% end %}
    # end

    def map_with(*args, &block)
      MultiIndexable.map_with(self, *args) do |*elems|
        yield *elems
      end
    end

    def map_with(*args : *U, &block) forall U
      {% begin %}

      # NOTE: To determine the return type 
      {% for i in 0...(U.size) %}
        {% if U[i] < MultiIndexable %}
          dummy{{i}} = uninitialized typeof(args[{{i}}].first)
        {% else %}
          dummy{{i}} = uninitialized typeof(args[{{i}}])
        {% end %}
      {% end %}

      buffer = Pointer(typeof(yield(self.first, {% for i in 0...(U.size) %}dummy{{i}},{% end %}))).malloc(size)
      idx = 0

      MultiIndexable.each_with(self, *args) do |*elems|
        buffer[idx] = yield *elems
        idx += 1
      end

      slice = Slice.new(buffer, size)
      NArray.of_buffer(shape, slice)
      {% end %}
    end
    
    def self.each_with(*args : *U, &block) forall U
      {% begin %}
        {% found_first = false %}
        {% for i in 0...(U.size) %}
          {% if U[i] < MultiIndexable %}
            {% if found_first == false %}
              {% found_first = true %}
              first = args[{{i}}]
            {% else %}
              raise ShapeError.new("Could not simultaneously map MultiIndexables with shapes #{args[{{i}}].shape} and #{first.shape}.") unless args[{{i}}].shape == first.shape
            {% end %}
          {% end %}
        {% end %}
        
        first.each_coord do |coord|
          yield(
            {% for i in 0...(U.size) %}
              {% if U[i] < NArray %} args[{{i}}].unsafe_fetch_element(coord) {% else %} args[{{i}}]{% end %},
            {% end %}
          )
        end
      {% end %}
    end


    def apply : ApplyProxy
      ApplyProxy.of(self)
    end

    # def apply! : ApplyProxy
    # end

    # def map(*others : MultiIndexable)
    # end

    # def NArray::map(*others : NArray)
    # end

    private class ApplyProxy(S, T)
      @src : S
  
      def self.of(src : S) forall S
        ApplyProxy(S, typeof(src.first)).new(src)
      end
      
      protected def initialize(@src)
      end
  
      # If a method signature not defined on {{@type}} is called, then `method_missing` will attempt
      # to apply the method to every element contained in the {{@type}}. Any argument to the method call
      # that is also an {{@type}} will be applied element-wise.
      # For example:
      # ```arr = {{@type}}(Int32).new([2,2,2]) { |i| i }
      # arr > 4```
      # will give: [[[false, false], [false, false]], [[false, true], [true true]]]
      # WARNING: fully exhaustive testing is not possible for this method; use at your own risk.
      # If a method is defined on both {{@type}} and the type parameter T, precedence will be
      # given to {{@type}}. Complex overloading may cause problems.
      macro method_missing(call)
              def {{call.name.id}}(*args : *U) forall U
              \{% if !@type.type_vars[1].has_method?({{call.name.id.stringify}}) %}
                  \{% raise( <<-ERROR
                              undefined method '{{call.name.id}}' for #{@type.type_vars[1]}.
                              Phase is attempting to apply `{{call.name.id}}`, an unknown method, to each element of an `#{@type.type_vars[0]}`. 
                              (See the documentation of `#{@type}#method_missing` for more info). 
                              For the source of the error, use `--error-trace`.
                              ERROR
                              ) %}
                  \{% end %}
                
                  @src.map_with(*args) do |elem, *arg_elems|
                    elem.{{call.name.id}}(*arg_elems)
                  end
              end
          end
    end
  end
end
