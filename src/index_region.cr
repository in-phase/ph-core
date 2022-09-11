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

    # Gets the region including all coordinates in the given bound_shape
    def self.cover(bound_shape : Indexable(T), *, drop : Bool = DROP_BY_DEFAULT, degeneracy : Array(Bool)? = nil)
      first = Array.new(bound_shape.size, T.zero)
      step = bound_shape.map { |x| x == 0 ? 0 : 1 }
      last = bound_shape.map { |x| {T.zero, x.pred}.max }
      shape = bound_shape.clone
      new(first, step, last, shape, drop, degeneracy)
    end

    # creates an indexRegion from positive, bounded literals
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

    protected def self.new(first, step = nil, *, last : Indexable(T))
      if !step
        step = first.map_with_index { |s, i| last[i] <=> s }
      end

      shape = first.zip(last, step).map { |vals| RangeSyntax.get_size(*vals) }
      new(first, step, last, shape, DROP_BY_DEFAULT)
    end

    protected def self.new(first, step = nil, *, shape : Indexable(T))
      if !step
        step = first.map_with_index { |s, i| last[i] <=> s }
      end
      last = first.zip(step, shape).map { |x0, dx, size| x0 + dx * size }
      new(first, step, last, shape, DROP_BY_DEFAULT)
    end

    protected def initialize(@first, @step, @last, @proper_shape : Indexable(T), @drop : Bool, degeneracy : Array(Bool)? = nil)
      @degeneracy = degeneracy || Array(Bool).new(@proper_shape.size, false)

      @reduced_shape = @proper_shape.dup
      unless degeneracy.nil?
        reduce_shape
      end
    end

    protected def reduce_shape 
      if @drop
        @reduced_shape = drop_degenerate(@proper_shape){ [@proper_shape.product] }
      else
        @reduced_shape = @proper_shape.dup 
      end
    end

    # ============= Methods required by MultiIndexable ===========================
    def shape : Array(T)
      @reduced_shape.dup
    end

    # TODO: *drop* isn't being used here, why is it included?
    def shape_internal(drop = MultiIndexable::DROP_BY_DEFAULT)
      @reduced_shape
    end

    def proper_dimensions : Int32
      @proper_shape.size
    end

    # composes regions
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

    # gets absolute coordinate of a coord in the region's local reference frame
    def unsafe_fetch_element(coord : Coord) : Array(T)
      local_to_absolute_unsafe(coord.to_a)
    end

    def first
      @first.clone
    end

    def last
      @last.clone
    end

    # ========================== Other =====================================

    def stride
      @step.clone
    end

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

    def trim!(bound_shape : Shape) : self
      if bound_shape.size != proper_dimensions
        # BETTER_ERROR
        raise DimensionError.new("invalid error :)")
      end

      bound_shape.each_with_index do |container_size, axis|
        @first[axis], @step[axis], @last[axis], @proper_shape[axis] =
          IndexRegion.trim_axis(container_size, @first[axis], @step[axis], @last[axis], @proper_shape[axis])
      end

      reduce_shape
      self
    end

    # DISCUSS: trim! that can trim off the closer-to-0 side also?
    # e.g. trim so all coordinates are above [3]

    def reverse! : IndexRegion(T)
      @first, @last = @last, @first
      @step = @step.map &.-
      self
    end

    def reverse : self
      clone.reverse!
    end

    def trim(bound_shape) : self
      self.clone.trim!(bound_shape)
    end

    # WARNING: this allows for the creation of IndexRegions with negative ordinates,
    # which may cause undocumented behaviour elsewhere in the code. The burden
    # is on the user to ensure that negative ordinates are not created, or that
    # they are appropriately handled.
    def unsafe_translate!(by offset : Enumerable) : self
      offset.each_with_index do |amount, axis|
        @first[axis] += amount
        @last[axis] += amount
      end
      self
    end

    def translate!(by offset : Enumerable) : self 
      offset.each_with_index do |amount, axis|
        if amount < 0 && (@first[axis] < -amount || @last[axis] < -amount)
          # BETTER_ERROR
          raise IndexError.new("Can't translate to negative indices")
        end
      end
      unsafe_translate!(offset)      
    end

    def translate(by offset : Enumerable) : self
      self.clone.translate!(offset)
    end

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

    def local_to_absolute(coord)
      get(coord)
    end

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

    def absolute_to_local(coord)
      if !includes?(coord)
        raise IndexError.new("Could not convert coordinate: #{coord} does not exist in region #{self}")
      end
      absolute_to_local_unsafe(coord)
    end

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

    def each : LexIterator(T)
      # TODO: Discuss if this should return LexIterator or maybe just Iterator(Indexable(I))
      LexIterator.new(self)
    end

    protected def drop_degenerate(arr : Array, &when_empty : -> Array(T)) : Array(T)
      new_arr = Array(T).new(arr.size)
      arr.each_with_index do |value, idx|
        new_arr << value unless @degeneracy[idx]
      end
      # If every axis was dropped, you must have a scalar
      return yield if new_arr.empty?
      new_arr
    end

    protected def package_range(axis)
      {first: @first[axis], step: @step[axis], last: @last[axis], size: @proper_shape[axis]}
    end

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
