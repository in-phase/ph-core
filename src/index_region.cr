require "./coord_util"
require "./multi_indexable"
require "./type_aliases"

module Phase
  # An `IndexRegion` represents the relationship between the coordinates in a source `MultiIndexable` and
  # the coordinates of its slicing. For example:
  # ```crystal
  # # This is the "source MultiIndexable" referred to above
  # narr = NArray[['a', 'b', 'c'],
  #               ['d', 'e', 'f'],
  #               ['g', 'h', 'i']]
  # 
  # # And this is a possible slicing of it:
  # sliced = narr[0..2.., 1..]
  # puts sliced # => [['b', 'c'],
  #             #     ['h', 'i']]
  # 
  # # An `IndexRegion` is a function from a coordinate in the context of `sliced`
  # # to a coordinate in the original `NArray`. We can see this by creating an
  # # `IndexRegion` via the source shape and the slicing operation:
  # mapping = IndexRegion.new(region_literal: [0..2.., 1..], bound_shape: narr.shape)
  # 
  # # sliced[0, 0] has the same element as narr[0, 1]
  # puts mapping.get(0, 0) # => [0, 1]
  # 
  # # sliced[1, 1] has the same element as narr[2, 2]
  # puts mapping.get(1, 1) # => [2, 2]
  # 
  # # We can even print the whole `IndexRegion` to see where
  # # each element of sliced is coming from:
  # puts mapping.to_narr
  # # 2x2 Phase::NArray(Array(Int32))
  # # [[[0, 1], [0, 2]],
  # #  [[2, 1], [2, 2]]]
  # 
  # # Phase uses this internally to compute slicing!
  # narr[mapping] == sliced # => true
  # ```
  struct IndexRegion(T)
    # See `MultiIndexable::DROP_BY_DEFAULT`
    DROP_BY_DEFAULT = MultiIndexable::DROP_BY_DEFAULT

    # DISCUSS: should it be a MultiIndexable?
    # should .each give an iterator over dimensions, or over coords?
    include MultiIndexable(Array(T))

    # The coordinates of the "corners" of this `IndexRegion`. For example,
    # if the region literal is `[1..3, 5..-2..1]`, the "first corner" is `[1, 5]` - 
    # the first ordinate on the axis 0 range is 1, and the first ordinate on axis 1 is 5.
    # Similarly, the `last` coordinate is `[3, 1]`.
    # Note that if and only if `@step[i] == 0`, then `@first[i]` and `@last[i]` will be
    # meaningless, as an empty set of coordinates has no corners. See `@step`.
    @first : Array(T)
    @last : Array(T)

    # @first, @last, @proper_shape, @reduced_shape must all be valid index representers but @step need not be (e.g. may be negative)
    # TODO: see if there is a way to generalize to any SignedInt
    # The step size along each axis of the region literal. For example, the region literal
    # `[3, 1..3, 5..-2..1]` would have a @step array of `[1, 1, -2]`.
    # This variable has a few edge cases to take note of:
    # - `a..b`, `a..`, `a...b`, and `a...` all have a step size of 1
    # - `a` has a step size of 1
    # - `a..x..a`, `a..x..b`, and `a...x..b` have a step size of x
    # - A step size of 0 along an axis means that it has zero valid indexes on that axis (e.g. this is an empty IndexRegion)
    # The lattermost case can be demonstrated as such:
    # `IndexRegion.cover([0, 1]).@size # => [0, 1]`
    # TODO: We probably want to make a clearer mechanism to indicate an empty IndexRegion
    @step : Array(Int32)
    
    # The shape of this `IndexRegion` in the full number of dimensions as its output coordinates.
    # E.g. `IndexRegion(Int32).new([1, 1..5])` has `@proper_shape == [1, 5]` regardless of
    # whether dimension dropping is enabled.
    @proper_shape : Array(T)

    # The shape of this `IndexRegion` once integer-indexed dimension dropping is applied.
    # (see `MultiIndexable::DROP_BY_DEFAULT`).
    # E.g. `IndexRegion(Int32).new([1, 1..5], drop: true)` has `@reduced_shape == [5]`,
    # `IndexRegion(Int32).new([1..1, 1..5], drop: true)` has `@reduced_shape == [1, 5]`,
    # and `IndexRegion(Int32).new([1, 1..5], drop: false)` has `@reduced_shape == [1, 5]`
    @reduced_shape : Array(T)

    # Stores the user-hinted dimension dropping information from the region
    # literal. For example: `IndexRegion(Int32).new(1, 1..1, 1..2)` has
    # `@degeneracy == [true, false, false]` because axis 0 was an integer
    # (droppable) whereas axis 1 and 2 were both ranges (and thus aren't
    # reliably droppable). This array will be populated regardless of if
    # dimension dropping is enabled. If this `IndexRegion` does not correspond
    # to a region literal (e.g. `IndexRegion.cover(shape)`), @degeneracy should
    # be populated with `false`.
    property degeneracy : Array(Bool)

    # Whether or not dimensions should be dropped.
    getter drop : Bool

    def_equals_and_hash @first, @step, @last, @degeneracy, @drop
    def_clone

    # =========================== Constructors ==============================

    # Copy constructor that throws a `ShapeError` if *region* doesn't fit inside of *bound_shape*.
    # (see `IndexRegion#fits_in?`)
    #
    # ```crystal
    # src = IndexRegion.cover([3, 4]) # => IndexRegion[0..2, 0..3]
    # IndexRegion.new(src, [4, 4]) # => IndexRegion[0..2, 0..3]
    # IndexRegion.new(src, [2, 2]) # => ShapeError
    # ```
    def self.new(region : IndexRegion, bound_shape : Shape)
      if region.fits_in?(bound_shape)
        return region.clone
      end

      raise ShapeError.new("Region #{region} does not fit inside #{bound_shape}")
    end

    # Creates an `IndexRegion` by clipping the *region_literal* to fit inside of the shape *trim_to*.
    # By default, only absolute (positive) ordinates can be used in the region
    # literal - however, if a *bound_shape* is passed, relative (negative / unbounded)
    # indexing can be used, and will refer to it.
    # 
    # ```crystal
    # # Using *trim_to* allows you to clip a region to a shape
    # IndexRegion.new([0..5, 1..2], trim_to: [2, 2]) # => IndexRegion[0..1, 1..1]
    # 
    # # A *bound_shape* lets you use relative indexes
    # IndexRegion.new([.., 2..-2], bound_shape: [3, 5], trim_to: [2, 3]) # => IndexRegion[0..1, 2..2]
    # 
    # # This method won't throw, but it *will* return an empty
    # # IndexRegion if the *region_literal* doesn't fit in *trim_to*.
    # IndexRegion.new([5..8], trim_to: [3]) # => IndexRegion[0..0..0]
    # ```
    def self.new(region_literal : Enumerable, bound_shape : Indexable? = nil, drop : Bool = DROP_BY_DEFAULT,
                 *, trim_to : Shape(T))
      first = Array.new(trim_to.size, T.zero)
      step = Array.new(trim_to.size, 1)
      last = Array.new(trim_to.size, T.zero)
      shape = Array.new(trim_to.size, T.zero)
      degeneracy = Array(Bool).new(trim_to.size, false)

      # you can only use negative indexes as relative offsets if you've explicitly passed the bound
      # shape that they should reference.
      allow_relative = !bound_shape.nil?
      bound_shape ||= trim_to

      region_literal.each_with_index do |range, i|
        RangeSyntax.ensure_nonnegative(range) unless allow_relative
        r = RangeSyntax.infer_range(range, bound_shape[i])
        first[i] = r[:first]
        step[i] = r[:step]
        last[i] = r[:last]
        shape[i] = r[:size]

        if range.is_a? Int
          degeneracy[i] = drop
        end
      end

      # The region literal is allowed to have implicit dimensions (fewer than the bound_shape would imply).
      # this loop just populates the remaining dimensions with sensible defaults
      (region_literal.size...bound_shape.size).each do |axis|
        # TODO handle bound_shape given with 0
        last[axis] = bound_shape[axis] - 1
        shape[axis] = bound_shape[axis]
      end

      new(first, step, last, shape, drop, degeneracy).trim!(trim_to)
    end

    # Creates an `IndexRegion` from a *region_literal*, using *bound_shape* for relative index handling.
    # This is the most commonly used `IndexRegion` constructor. If the region literal
    # has fewer dimensions than *bound_shape*, then the latter axes will be inferred as `..`.
    #
    # ```crystal
    # # Normal usage
    # IndexRegion.new([1...5, ..-3], [5, 5]) # => IndexRegion[1..4, 0..2]
    # 
    # # If the region literal is shorter than the bound shape, it
    # # is filled with trailing ".."s
    # IndexRegion.new([1], [2, 3])     # => IndexRegion[1, 0..2]
    # IndexRegion.new([1, ..], [2, 3]) # => IndexRegion[1, 0..2]
    # 
    # # If the region literal is longer than the bound shape, a
    # # DimensionError is raised
    # IndexRegion.new([.., 3], [3]) # => DimensionError
    # 
    # # If the region literal is out of bounds, an IndexError
    # # is raised
    # IndexRegion.new([5..10], [2]) # => IndexError
    # IndexRegion.new([5..10], [-2]) # => IndexError
    # ```
    def self.new(region_literal : Enumerable, bound_shape : Indexable(T), drop : Bool = DROP_BY_DEFAULT) : IndexRegion(T)
      first = Array.new(bound_shape.size, T.zero)
      step = Array.new(bound_shape.size, 1)
      last = Array.new(bound_shape.size, T.zero)
      shape = Array.new(bound_shape.size, T.zero)
      degeneracy = Array(Bool).new(bound_shape.size, false)

      if region_literal.size > bound_shape.size
        raise DimensionError.new("The region literal #{region_literal} had more dimensions than its bound shape #{bound_shape}")
      end

      region_literal.each_with_index do |range, i|
        r = RangeSyntax.canonicalize_range(range, bound_shape[i])
        first[i] = r[:first]
        step[i] = r[:step]
        last[i] = r[:last]
        shape[i] = r[:size]

        if range.is_a? Int
          degeneracy[i] = drop
        end
      end

      # The region literal is allowed to have implicit dimensions (fewer than the bound_shape would imply).
      # this loop just populates the remaining dimensions with sensible defaults
      (region_literal.size...bound_shape.size).each do |axis|
        # TODO handle bound_shape given with 0
        last[axis] = bound_shape[axis] - 1
        shape[axis] = bound_shape[axis]
      end

      new(first, step, last, shape, drop, degeneracy)
    end

    # Creates an `IndexRegion` whose coordinates fully cover the given *bound_shape*.
    # ```crystal
    # IndexRegion.cover([2, 3]).to_narr # => 2x3 Phase::NArray(Array(Int32))
    #                                   #    [[[0, 0], [0, 1], [0, 2]],
    #                                   #     [[1, 0], [1, 1], [1, 2]]]
    # ```
    def self.cover(bound_shape : Shape(T), *, drop : Bool = DROP_BY_DEFAULT, degeneracy : Array(Bool)? = nil)
      first = Array.new(bound_shape.size, T.zero)
      step = bound_shape.map { |x| x == 0 ? 0 : 1 }
      last = bound_shape.map { |x| {T.zero, x.pred}.max }
      shape = bound_shape.clone
      new(first, step, last, shape, drop, degeneracy)
    end

    # Creates an `IndexRegion` from an absolute (positive, bounded) *region_literal*.
    # This allows you to bypass the usual requirement of passing a *bound_shape*, which
    # is usually needed in order to process negative or nil indexes.
    # ```crystal
    # IndexRegion.new([1, 2...5]) # => IndexRegion[1, 2..4]
    # IndexRegion.new([..]) # => Exception (TODO: pick a better exception)
    # IndexRegion.new([-1]) # => Exception (TODO: pick a better exception)
    # ```
    def self.new(region_literal : RegionLiteral, drop : Bool = DROP_BY_DEFAULT)
      dims = region_literal.size
      first = Array(T).new(dims, T.zero)
      step = Array(Int32).new(dims, 0)
      last = Array(T).new(dims, T.zero)
      shape = Array(T).new(dims, T.zero)
      degeneracy = Array(Bool).new(dims, false)

      region_literal.each_with_index do |range, i|
        RangeSyntax.ensure_nonnegative(range)
        if !RangeSyntax.bounded?(range)
          # TODO: better error message
          raise "Cannot create IndexRegion without an explicit upper bound unless you provide a bounding shape"
        end

        if range.is_a? Int
          degeneracy[i] = true
        end

        r = RangeSyntax.infer_range(range, T.zero)
        first[i] = r[:first]
        step[i] = r[:step]
        last[i] = r[:last]
        shape[i] = r[:size]
      end

      new(first, step, last, shape, drop, degeneracy)
    end

    # Produces an `IndexRegion` given that the *first* and *last* coordinates are already known.
    # A *step* size can be provided if present, but if not, the steps will be
    # inferred to be -1, 0, or 1.
    # TODO: Code sample
    protected def self.new(first, step = nil, *, last : Indexable(T))
      if !step
        # If step isn't defined, populate it with +/- 1 depending on the order of first and last
        step = first.map_with_index { |s, i| last[i] <=> s }
      end

      shape = first.zip(last, step).map { |vals| RangeSyntax.get_size(*vals) }
      new(first, step, last, shape, DROP_BY_DEFAULT)
    end

    # Automatically populates the reduced shape (and optionally degeneracy) of an otherwise fully defined `IndexRegion`.
    protected def initialize(@first, @step, @last, @proper_shape : Indexable(T), @drop : Bool, degeneracy : Array(Bool)? = nil)
      # If no degeneracy information exists, we keep all the axes
      @degeneracy = degeneracy || Array(Bool).new(@proper_shape.size, false)
      @reduced_shape = IndexRegion.compute_reduced_shape(@proper_shape, @degeneracy, @drop)
    end

    # Produces a new Array that only contains the values `arr[i]` where `degeneracy[i]` is false.
    # In the case that *degeneracy* is true (all axes are dropped), the caller must produce
    # a sensible return value via the block argument.
    #
    # This is used in several places to reduce the number of dimensions of some output array
    # in accordance with dimension dropping rules.
    protected def self.drop_degenerate(arr : Array(T), degeneracy : Array(Bool), &when_empty : -> Array(T)) : Array(T) forall T
      new_arr = Array(T).new(arr.size)

      arr.each_with_index do |value, idx|
        new_arr << value unless degeneracy[idx]
      end

      return yield if new_arr.empty?
      new_arr
    end

    # See `IndexRegion.drop_degenerate`.
    protected def drop_degenerate(arr : Array, &when_empty : -> Array(T)) : Array(T)
      IndexRegion.drop_degenerate(arr, @degeneracy) { yield }
    end

    # Computes the reduced shape of an `IndexRegion` given its *proper_shape*, *degeneracy* and *drop* value.
    # More specifically, it drops axes off of the *proper_shape* where appropriate, and handles the
    # scalar case.
    protected def self.compute_reduced_shape(proper_shape : Shape, degeneracy : Array(Bool), drop : Bool)
      if drop
        drop_degenerate(proper_shape, degeneracy) do
          # This block is only called when all of the axes are degenerate. That
          # means that the IndexRegion selects a single element, or that the
          # IndexRegion contains no elements at all. In both of these cases,
          # we want the reduced shape to be 1d and contain either 0 or 1 elements:
          [proper_shape.product]
        end
      else
        proper_shape.dup
      end
    end

    # ============= Methods required by MultiIndexable ===========================
    # TODO: *drop* isn't being used here, why is it included?
    def shape_internal(drop = MultiIndexable::DROP_BY_DEFAULT) : Array(T)
      @reduced_shape
    end

    # Returns the number of dimensions of the space that this `IndexRegion` maps into.
    # For example:
    # ```crystal
    # #                          region   proper shape
    # idx_r = IndexRegion.new([1, .., ..], [5, 5, 5])
    # 
    # # The IndexRegion above describes a 2D region (a matrix)
    # puts idx_r.dimensions # => 2
    # 
    # # But the matrix draws out of a 3D MultiIndexable:
    # puts idx_r.proper_dimensions # => 3
    # ```
    def proper_dimensions : Int32
      @proper_shape.size
    end

    # :ditto:
    def unsafe_fetch_chunk(region : IndexRegion, drop : Bool) : IndexRegion(T)
      # Because IndexRegions store not just shape, but also positional information (the first element is
      # not always the zero coordinate), it isn't safe to drop a dimension fully. The best we can do
      # is take the elementwise OR of the degeneracies of `self` and `region`, which means that when
      # the IndexRegion is used to get a chunk, it will return an object with the proper number of dimensions.
      if drop
        @degeneracy.map_with_index do |el, idx|
          el || region.degeneracy[idx]
        end
      end

      # get the indexes where its true
      # remove the elements at those indexes and shrink all the arrays accordingly
      new_first = local_to_absolute_unsafe(region.first)
      new_last = local_to_absolute_unsafe(region.last)

      new_step = @step.map_with_index do |outer_step, i|
        outer_step * region.step.unsafe_fetch(i)
      end
      IndexRegion(T).new(new_first, new_step, new_last, region.shape)
    end

    # :ditto:
    def unsafe_fetch_element(coord : Coord) : Array(T)
      local_to_absolute_unsafe(coord.to_a)
    end

    # Returns a copy of the coordinate of the first "corner" in this `IndexRegion`.
    # For example, if the region literal is `[1..3, 5..-2..1]`, the "first
    # corner" is `[1, 5]` - the first ordinate on the axis 0 range is 1, and
    # the first ordinate on axis 1 is 5.
    # Similarly, the `last` coordinate is `[3, 1]`.
    # Note that if and only if `@step[i] == 0`, then `@first[i]` and `@last[i]` will be
    # meaningless, as an empty set of coordinates has no corners. See `@step`.
    def first
      @first.clone
    end

    # Similar to `IndexRegion#first`.
    # For example, if the region literal is `[1..3, 5..-2..1]`, the "last
    # corner" is `[3, 1]` - the last ordinate on the axis 0 range is 3, and
    # the last ordinate on axis 1 is 1.
    def last
      @last.clone
    end

    # ========================== Other =====================================

    # Returns the spacing between elements along each axis.
    # For example, if the region literal is `[1..3, 5..-2..1]`, the
    # stride on axis 0 is `1` (by default), and the stride on axis 1 is
    # `-2` (as written in the region literal). Thus, calling `#stride` on
    # the corresponding `IndexRegion` would yield `[1, -2]`.
    # ```crystal
    # idx_r = IndexRegion(Int32).new([1..3, 5..-2..1])
    # puts idx_r.stride # => [1, -2]
    # ```
    def stride
      @step.clone
    end

    # Returns true if this `IndexRegion` points to the provided *coord*.
    # For example:
    # ```crystal
    # 
    # idx_r = IndexRegion(Int32).new([0..3, 5..7])
    #
    # # This IndexRegion maps the input coordinate [0, 0] to [0, 5]
    # idx_r.get(0, 0) # => [0, 5]
    #
    # # And thus it includes [0, 5]
    # idx_r.includes? [0, 5] # => true
    #
    # # On the other hand, no input coordinate will map to [10, 10]
    # idx_r.includes? [10, 10] # => false
    #
    # # Don't confuse input and output coordinates, here! Like all
    # # `MultiIndexable`s, idx_r implements `#has_coord?`. `#includes?`
    # # refers to the values (output coordinates) of the `IndexRegion`,
    # # whereas `#has_coord?` refers to the input coordinates.
    # idx_r.includes? [0, 0] # => false
    # idx_r.has_coord? [0, 0] # => true
    # ```
    def includes?(coord : InputCoord)
      # DISCUSS: DimensionError or return false?
      return false unless coord.size == proper_dimensions
      coord.each_with_index do |ord, i|
        if @step.unsafe_fetch(i) > 0
          bounds = @first.unsafe_fetch(i)..@last.unsafe_fetch(i)
        else
          bounds = @last.unsafe_fetch(i)..@first.unsafe_fetch(i)
        end
        return false unless bounds.includes?(ord)
        return false unless (ord - @first.unsafe_fetch(i)) % @step.unsafe_fetch(i) == 0
      end
      true
    end

    # Returns true if this `IndexRegion` contains coordinates that all fit inside of
    # the given *bound_shape*. For example:
    # ```crystal
    # idx_r = IndexRegion.new(region_literal: [1..2..], bound_shape: [5])
    # idx_r.to_narr # => [[1], [3]]
    # 
    # idx_r.fits_in?([3]) # => false
    # idx_r.fits_in?([4]) # => true
    # idx_r.fits_in?([4, 4]) # => DimensionError
    # ```
    def fits_in?(bound_shape : Shape) : Bool 
      if bound_shape.size != proper_dimensions
        raise DimensionError.new("The bound shape provided had a different number of dimensions than this IndexRegion, so fits_in? is meaningless.")
      end

      bound_shape.map_with_index do |bound, i|
        return false if bound <= {@first.unsafe_fetch(i), @last.unsafe_fetch(i)}.max
      end

      true
    end

    # Clips this `IndexRegion` in-place to fit the *bound_shape* provided.
    # 
    # ```crystal
    # a = IndexRegion(Int32).new([1..3, 10..-2..0])
    # puts a # => IndexRegion[1..3, 10..-2..0]
    # 
    # # Trimming to a shape that `a` fits in has no effect:
    # a.trim!([100, 100])
    # puts a # => IndexRegion[1..3, 10..-2..0]
    # 
    # a.trim!([2, 3])
    # puts a # => IndexRegion[1..1, 2..-2..0]
    # 
    # # It's possible to recieve an empty result after trimming
    # b = IndexRegion(Int32).new([5..6])
    # b.trim!([0])
    # puts b # => IndexRegion[0..0..0] (no elements)
    # 
    # # When using the wrong number of dimensions, a DimensionError is raised
    # c = IndexRegion(Int32).new([5..4])
    # c.trim!([4, 3]) # => DimensionError
    # ```
    def trim!(bound_shape : Shape) : self
      if bound_shape.size != proper_dimensions
        # BETTER_ERROR
        raise DimensionError.new("invalid error :)")
      end

      bound_shape.each_with_index do |container_size, axis|
        @first[axis], @step[axis], @last[axis], @proper_shape[axis] =
          IndexRegion.trim_axis(container_size, @first[axis], @step[axis], @last[axis], @proper_shape[axis])
      end

      @reduced_shape = IndexRegion.compute_reduced_shape(@proper_shape, @degeneracy, @drop)
      self
    end

    # DISCUSS: trim! that can trim off the closer-to-0 side also?
    # e.g. trim so all coordinates are above [3]

    # Reverses the ordering of an `IndexRegion` in place.
    # For example:
    # ```crystal
    # idx_r = IndexRegion(Int32).new([0..2..2])
    # narr = NArray['a', 'b', 'c']
    #
    # idx_r.each { |coord| puts coord } # => [0], [2]
    # narr[idx_r] # => NArray['a', 'c']
    # 
    # idx_r.reverse!
    # idx_r.each { |coord| puts coord } # => [2], [0]
    # narr[idx_r] # => NArray['c', 'a']
    # ```
    def reverse! : IndexRegion(T)
      @first, @last = @last, @first
      @step = @step.map &.-
      self
    end

    # Returns a reversed copy of this `IndexRegion`. See `#reverse!`.
    def reverse : self
      clone.reverse!
    end

    # Returns a trimmed copy of this `IndexRegion`. See `#trim!`.
    def trim(bound_shape) : self
      self.clone.trim!(bound_shape)
    end

    # Translates an `IndexRegion` in place, without checking that the result is valid.
    # See `#translate!`.
    # WARNING: this allows for the creation of IndexRegions with negative ordinates,
    # which may cause undocumented behaviour elsewhere in the code. The burden
    # is on the user to ensure that negative ordinates are not created, or that
    # they are appropriately handled.
    def unsafe_translate!(offset : Enumerable) : self
      offset.each_with_index do |amount, axis|
        @first[axis] += amount
        @last[axis] += amount
      end
      self
    end

    # Translates this `IndexRegion` in place by adding an *offset* to each output coordinate.
    # For example:
    # ```crystal
    # idx_r = IndexRegion(Int32).new([0, 5..-2..0])
    # puts idx_r # => IndexRegion[0, 5..-2..1]
    # 
    # idx_r.translate!([1, -1])
    # puts idx_r # => IndexRegion[1, 4..-2..0]
    #
    # IndexRegions only output canonical coordinates. This
    # translation would produce negative ordinates in the output coords,
    # which is illegal.
    # idx_r.translate!([-10, -10]) # => IndexError
    # ```
    def translate!(offset : Enumerable) : self 
      offset.each_with_index do |amount, axis|
        if amount < 0 && (@first[axis] < -amount || @last[axis] < -amount)
          # BETTER_ERROR
          raise IndexError.new("Can't translate to negative indices")
        end
      end
      unsafe_translate!(offset)      
    end

    # Returns a translated copy of this `IndexRegion`. See `#translate!`.
    def translate(offset : Enumerable) : self
      self.clone.translate!(offset)
    end

    # :ditto:
    def to_s(io : IO)
      io << "IndexRegion"
      io << @degeneracy.map_with_index do |degen, i|
        if degen
          @first[i]
        elsif @step[i].abs == 1
          @first[i]..@last[i]
        else
          @first[i]..@step[i]..@last[i]
        end
      end
    end

    # Maps a local (input) coordinate to its corresponding absolute (output) coordinate.
    # This is equivalent to using `IndexRegion#[](coord)`, but it is aliased
    # here in order to make `IndexRegion` code easier to reason
    # about.
    # For example:
    # ```crystal
    # idx_r = IndexRegion(Int32).new([3..5, 2..1])
    # idx_r.local_to_absolute([0, 0]) # => [3, 2]
    # idx_r[0, 0] # => [3, 2]
    # ```
    def local_to_absolute(coord)
      get(coord)
    end

    # Unsafe version of `#local_to_absolute` that does not check if *coord* is in bounds for this `IndexRegion`.
    def local_to_absolute_unsafe(coord : Coord) : Array(T)
      if @drop
        local_axis = 0
        degeneracy.map_with_index do |degenerate, i|
          if degenerate
            @first.unsafe_fetch(i)
          else
            local_axis += 1
            @first.unsafe_fetch(i) + coord.unsafe_fetch(local_axis - 1) * @step.unsafe_fetch(i)
          end
        end
      else
        coord.map_with_index do |ord, i|
          @first[i] + ord * @step[i]
        end
      end
    end

    # Maps an absolute (output) coordinate to its corresponding local (input) coordinate.
    # ```crystal
    # idx_r = IndexRegion(Int32).new([3..5, 2..1])
    # idx_r.absolute_to_local([3, 2]) # => [0, 0]
    # idx_r.absolute_to_local([4, 2]) # => [1, 0]
    # idx_r.absolute_to_local([5, 1]) # => [2, 1]
    # ```
    def absolute_to_local(coord)
      if !includes?(coord)
        raise IndexError.new("Could not convert coordinate: #{coord} does not exist in region #{self}")
      end
      absolute_to_local_unsafe(coord)
    end

    # Unsafe version of `#absolute_to_local` that does not check if *coord* is in bounds for this `IndexRegion`.
    def absolute_to_local_unsafe(coord)
      local = coord.map_with_index do |ord, i|
        (ord - @first.unsafe_fetch(i)) // @step.unsafe_fetch(i)
      end

      if @drop
        drop_degenerate(local) { [T.zero] }
      else
        local
      end
    end

    # :ditto:
    def each : LexIterator(T)
      # TODO: Discuss if this should return LexIterator or maybe just Iterator(Indexable(I))
      LexIterator.new(self)
    end

    # Returns a packaged range tuple (see `#trim_axis` for further description) for a given
    # *axis* of this `IndexRegion`. This is just an internal data structure used to communicate
    # the same information as `start..step..stop` normally would, except it's in a pre-parsed
    # form.
    protected def package_range(axis)
      {first: @first[axis], step: @step[axis], last: @last[axis], size: @proper_shape[axis]}
    end

    # Helper function that trims the range described by `{first, step, last}` such that it
    # fits within the range 0...new_bound. *size* must contain the number of elements
    # that exist in the range described. The output range is returned as a tuple in the
    # same order as the input - `{new_first, new_step, new_last, new_size}`.
    protected def self.trim_axis(new_bound, first : T, step, last, size) forall T
      if first >= new_bound
        if last >= new_bound # both out of bounds
          return {T.zero, 0, T.zero, T.zero}
        elsif step < 0 # We started too high, but terminate inside the bounds
          span = (new_bound - 1) - last
          size = span // step.abs + 1
          span -= span % step.abs

          return {last + span, step, last, T.new(size)}
        end
      elsif step > 0 && last >= new_bound # first in bounds, increase past bound
        span = (new_bound - 1) - first
        span -= span % step.abs
        size = span // step.abs + 1

        return {first, step, first + span, T.new(size)}
      end
      {first, step, last, T.new(size)}
    end
  end
end
