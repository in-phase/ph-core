require "./coord_util"
require "./multi_indexable"
require "./type_aliases"

module Phase
  struct IndexRegion(T)
    DROP_BY_DEFAULT = MultiIndexable::DROP_BY_DEFAULT

    # DISCUSS: should it be a MultiIndexable?
    # should .each give an iterator over dimensions, or over coords?
    include MultiIndexable(Array(T))

    # :nodoc:
    getter first : Array(T)

    # :nodoc:
    getter last : Array(T)

    # @first, @last, @proper_shape, @reduced_shape must all be valid index representers but @step need not be (e.g. may be negative)
    # TODO: see if there is a way to generalize to any SignedInt
    # :nodoc:
    getter step : Array(Int32)
    @proper_shape : Array(T)
    @reduced_shape : Array(T)

    property degeneracy : Array(Bool)
    getter drop : Bool

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
      step = Array.new(trim_to.size, T.zero + 1)
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
          degeneracy[i] = true
        end
      end

      # The region literal is allowed to have implicit dimensions (fewer than the bound_shape would imply).
      # this loop just populates the remaining dimensions with sensible defaults
      (region_literal.size...bound_shape.size).each do |axis|
        last[axis] = bound_shape[axis] - 1
        shape[axis] = bound_shape[axis]
      end

      new(first, step, last, shape, drop, degeneracy).trim!(trim_to)
    end

    # Main constructor
    def self.new(region_literal : Enumerable, bound_shape : Indexable(T), drop : Bool = DROP_BY_DEFAULT) : IndexRegion(T)
      first = Array.new(bound_shape.size, T.zero)
      step = Array.new(bound_shape.size, T.zero + 1)
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
          degeneracy[i] = true
        end
      end

      # The region literal is allowed to have implicit dimensions (fewer than the bound_shape would imply).
      # this loop just populates the remaining dimensions with sensible defaults
      (region_literal.size...bound_shape.size).each do |axis|
        last[axis] = bound_shape[axis] - 1
        shape[axis] = bound_shape[axis]
      end

      new(first, step, last, shape, drop, degeneracy)
    end

    # Gets the region including all coordinates in the given bound_shape
    def self.cover(bound_shape : Indexable(T), *, drop : Bool = DROP_BY_DEFAULT, degeneracy : Array(Bool)? = nil)
      first = Array.new(bound_shape.size, T.zero)
      step = Array.new(bound_shape.size, T.zero + 1)
      last = bound_shape.map &.pred
      shape = bound_shape.dup
      new(first, step, last, shape, drop, degeneracy)
    end

    # creates an indexRegion from positive, bounded literals
    def self.new(region_literal : Enumerable, drop : Bool = DROP_BY_DEFAULT)
      dims = region_literal.size
      first = Array(T).new(dims, T.zero)
      step = Array(T).new(dims, T.zero)
      last = Array(T).new(dims, T.zero)
      shape = Array(T).new(dims, T.zero)
      degeneracy = Array(Bool).new(dims, false)

      region_literal.each_with_index do |range, i|
        RangeSyntax.ensure_nonnegative(range)
        if !RangeSyntax.bounded?(range)
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

      if degeneracy.nil?
        @reduced_shape = @proper_shape.dup
      else
        @reduced_shape = drop_degenerate(@proper_shape) { [T.zero + 1] }
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

      new_step = @step.zip(region.step).map do |outer, inner|
        outer * inner
      end
      IndexRegion(T).new(new_first, new_step, new_last, region.shape)
    end

    # gets absolute coordinate of a coord in the region's local reference frame
    def unsafe_fetch_element(coord : Coord) : Array(T)
      local_to_absolute_unsafe(coord)
    end

    # ========================== Other =====================================

    def_clone

    def includes?(coord)
      coord.each_with_index do |value, i|
        bounds = (@step[i] > 0) ? (@first[i]..@last[i]) : (@last[i]..@first[i])
        return false unless bounds.includes?(value)
        return false unless (value - @first[i]) % @step[i] == 0
      end
      true
    end

    # TODO: check dimensions
    def fits_in?(bound_shape) : Bool
      bound_shape.zip(@first, @last).each do |bound, a, b|
        return false if bound <= {a, b}.max
      end
      true
    end

    # TODO
    def trim!(bound_shape) : self
      dims = @reduced_shape.size

      if bound_shape.size != dims
        raise DimensionError.new("invalid error :)")
      end

      bound_shape.each_with_index do |container_size, axis|
        @first[axis], @step[axis], @last[axis], @proper_shape[axis] =
          IndexRegion.trim_axis(container_size, @first[axis], @step[axis], @last[axis], @proper_shape[axis])
      end

      if @drop
        @reduced_shape = drop_degenerate(@proper_shape) { [T.zero + 1] }
      else
        @reduced_shape = @proper_shape.dup
      end
      self
    end

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

    def translate!(by offset : Enumerable) : self
      offset.each_with_index do |amount, axis|
        @first[axis] += amount
        @last[axis] += amount
      end
      self
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

    # TODO: in general, maybe use immediate methods rather than zip?
    def local_to_absolute_unsafe(coord)
      if @drop
        local_axis = 0
        degeneracy.map_with_index do |degenerate, i|
          if degenerate
            @first[i]
          else
            local_axis += 1
            @first[i] + coord[local_axis - 1] * @step[i]
          end
        end
      else
        coord.zip(@first, @step).map do |idx, first, step|
          first + idx * step
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
      local = coord.zip(@first, @step).map do |idx, first, step|
        (idx - first) // step
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

    protected def drop_degenerate(arr : Array, &when_full : -> Array(T)) : Array(T)
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

    protected def self.trim_axis(new_bound, first, step, last, size)
      if first >= new_bound
        if last >= new_bound # both out of bounds
          return {0, 0, 0, 0}
        elsif step < 0 # We started too high, but terminate inside the bounds
          span = (new_bound - 1) - last
          size = span // step.abs + 1
          span -= span % step.abs

          return {last + span, step, last, size}
        end
      elsif step > 0 && last >= new_bound # first in bounds, increase past bound
        span = (new_bound - 1) - first
        span -= span % step.abs
        size = span // step.abs + 1

        return {first, step, first + span, size}
      end
      {first, step, last, size}
    end
  end
end
