require "./coord_util"
require "./multi_indexable"
require "./type_aliases"

module Phase
  struct IndexRegion(T)
    DROP_BY_DEFAULT = MultiIndexable::DROP_BY_DEFAULT

    # DISCUSS: should it be a MultiIndexable?
    # should .each give an iterator over dimensions, or over coords?
    include MultiIndexable(Array(T))

    @first : Array(T)
    @last : Array(T)

    # @first, @last, @proper_shape, @reduced_shape must all be valid index representers but @step need not be (e.g. may be negative)
    # TODO: see if there is a way to generalize to any SignedInt
    @step : Array(Int32)
    
    @proper_shape : Array(T)
    @reduced_shape : Array(T)

    property degeneracy : Array(Bool)
    getter drop : Bool

    def_equals_and_hash @first, @step, @last, @degeneracy, @drop
    def_clone

    # =========================== Constructors ==============================

    def self.new(region : IndexRegion, bound_shape)
      if region.fits_in?(bound_shape)
        return region.clone
      end
      raise IndexError.new("Region #{region} does not fit inside #{bound_shape}")
    end

    # doesn't allow negative (relative) indices, and allows you to clip
    # a region_literal down so it will fit inside of *trim_to*.
    def self.new(region_literal : Enumerable, bound_shape : Indexable? = nil, drop : Bool = DROP_BY_DEFAULT,
                 *, trim_to : Indexable(T))
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

    # Main constructor
    def self.new(region_literal : Enumerable, bound_shape : Indexable(T), drop : Bool = DROP_BY_DEFAULT) : IndexRegion(T)
      first = Array.new(bound_shape.size, T.zero)
      step = Array.new(bound_shape.size, 1)
      last = Array.new(bound_shape.size, T.zero)
      shape = Array.new(bound_shape.size, T.zero)
      degeneracy = Array(Bool).new(bound_shape.size, false)

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
      step = Array.new(bound_shape.size, 1)
      # TODO handle bound_shape given with 0
      last = bound_shape.map &.pred
      shape = bound_shape.dup
      new(first, step, last, shape, drop, degeneracy)
    end

    # creates an indexRegion from positive, bounded literals
    def self.new(region_literal : Enumerable, drop : Bool = DROP_BY_DEFAULT)
      dims = region_literal.size
      first = Array(T).new(dims, T.zero)
      step = Array(Int32).new(dims, 0)
      last = Array(T).new(dims, T.zero)
      shape = Array(T).new(dims, T.zero)
      degeneracy = Array(Bool).new(dims, false)

      region_literal.each_with_index do |range, i|
        RangeSyntax.ensure_nonnegative(range)
        if !RangeSyntax.bounded?(range)
          # BETTER_ERROR
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

    def shape_internal(drop = MultiIndexable::DROP_BY_DEFAULT)
      @reduced_shape
    end

    def size
      @reduced_shape.product
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
      local_to_absolute_unsafe(coord)
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

    def includes?(coord)
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

    def fits_in?(bound_shape) : Bool 
      if bound_shape.size != proper_dimensions
        # DISCUSS: DimensionError or return false?
        return false
      end
      bound_shape.map_with_index do |bound, i|
        return false if bound <= {@first.unsafe_fetch(i), @last.unsafe_fetch(i)}.max
      end
      true
    end

    def trim!(bound_shape) : self
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

    def to_s(io)
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

    def local_to_absolute_unsafe(coord)
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

    def each : CoordIterator(T)
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
