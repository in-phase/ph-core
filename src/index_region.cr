require "./coord_util"
require "./multi_indexable"
require "./type_aliases"

module Phase
  struct IndexRegion(T)
    # DISCUSS: should it be a MultiIndexable?
    # should .each give an iterator over dimensions, or over coords?
    include MultiIndexable(Array(T))

    # :nodoc:
    getter start : Array(T)

    # :nodoc:
    getter stop : Array(T)

    # @start, @stop, @shape must all be valid index representers but @step need not be (e.g. may be negative)
    # TODO: see if there is a way to generalize to any SignedInt
    # :nodoc:
    getter step : Array(Int32)
    @shape : Array(T)

    property degeneracy : Array(Bool)

    # =========================== Constructors ==============================

    def self.new(region : IndexRegion, bound_shape)
      if region.fits_in?(bound_shape)
        return region.clone
      end
      raise IndexError.new("Region #{region} does not fit inside #{bound_shape}")
    end

    # doesn't allow negative (relative) indices, and allows you to clip
    # a region_literal down so it will fit inside of *trim_to*.
    def self.new(region_literal : Enumerable, *, trim_to : Indexable(T))
      idx_r = new(bound_shape: trim_to)
      region_literal.each_with_index do |range, i|
        IndexRegion.ensure_nonnegative(range)
        idx_r.start[i], idx_r.step[i], idx_r.stop[i], idx_r.@shape[i] = infer_range(range, trim_to[i])
        if range.is_a? Int
          idx_r.degeneracy[i] = true
        end
      end
      idx_r.trim!(trim_to)
    end

    # Main constructor
    def self.new(region_literal : Enumerable, bound_shape : Indexable(T)) : IndexRegion(T)
      idx_r = new(bound_shape: bound_shape)
      region_literal.each_with_index do |range, i|
        vals = canonicalize_range(range, bound_shape[i])
        idx_r.start[i], idx_r.step[i], idx_r.stop[i], idx_r.@shape[i] = vals

        if range.is_a? Int
          idx_r.degeneracy[i] = true
        end
      end
      idx_r
    end

    # Gets the region including all coordinates in the given bound_shape
    def self.cover(bound_shape : Indexable(T))
      new(bound_shape: bound_shape)
    end

    # creates an indexRegion from positive, bounded literals
    def self.new(region_literal : Enumerable)
        dims = region_literal.size
        start = Array(T).new(dims, T.zero)
        step = Array(T).new(dims, T.zero)
        stop = Array(T).new(dims, T.zero)
        shape = Array(T).new(dims, T.zero)
        degeneracy = Array(Bool).new(dims, false)

        region_literal.each_with_index do |range, i|
            IndexRegion.ensure_nonnegative(range)
            if !IndexRegion.bounded?(range)
                raise "Cannot create IndexRegion without an explicit upper bound unless you provide a bounding shape"
            end

            if range.is_a? Int
              degeneracy[i] = true
            end
            start[i], step[i], stop[i], shape[i] = IndexRegion.infer_range(range, T.zero)
        end

        new(start, step, stop, shape, degeneracy)
    end

    def self.new(start, step = nil, *, stop : Indexable(T))
      if !step
        step = start.map_with_index { |s, i| stop[i] <=> s }
      end

      shape = start.zip(stop, step).map { |vals| IndexRegion.get_size(*vals) }
      new(start, step, stop, shape)
    end

    def self.new(start, step = nil, *, shape : Indexable(T))
      if !step
        step = start.map_with_index { |s, i| stop[i] <=> s }
      end
      stop = start.zip(step, shape).map { |x0, dx, size| x0 + dx * size }
      new(start, step, stop, shape)
    end

    protected def self.new(*, bound_shape : Indexable(T))
      start = Array.new(bound_shape.size, T.zero)
      step = Array.new(bound_shape.size, T.zero + 1)
      stop = bound_shape.map &.pred
      shape = bound_shape.dup
      new(start, step, stop, shape)
    end

    protected def initialize(@start, @step, @stop, @shape : Indexable(T), degeneracy : Array(Bool)? = nil)
      @degeneracy = degeneracy || Array(Bool).new(@shape.size, false)
    end

    # ============= Methods required by MultiIndexable ===========================
    def shape(drop = MultiIndexable::DROP_BY_DEFAULT) : Array(T)
      return @shape.dup unless drop

      new_shape = Array(T).new(@shape.size)
      @shape.each_with_index do |dim, idx|
        new_shape << dim unless @degeneracy[idx]
      end

      # If every axis was dropped, you must have a scalar
      return [1] if new_shape.empty?
      new_shape
    end

    def shape_internal(drop = MultiIndexable::DROP_BY_DEFAULT)
      return @shape unless drop
      shape
    end

    def size
      @shape.product
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
      new_start = local_to_absolute(region.start)
      new_stop = local_to_absolute(region.stop)

      new_step = @step.zip(region.step).map do |outer, inner|
        outer * inner
      end
      IndexRegion(T).new(new_start, new_step, new_stop, region.shape)
    end

    # gets absolute coordinate of a coord in the region's local reference frame
    def unsafe_fetch_element(coord : Coord) : Array(T)
      local_to_absolute(coord)
    end

    # ========================== Other =====================================

    def_clone

    def includes?(coord)
      coord.each_with_index do |value, i|
        bounds = (@step[i] > 0) ? (@start[i]..@stop[i]) : (@stop[i]..@start[i])
        return false unless bounds.includes?(value)
        return false unless (value - @start[i]) % @step[i] == 0
      end
      true
    end

    # TODO: check dimensions
    def fits_in?(bound_shape) : Bool
      bound_shape.zip(@start, @stop).each do |bound, a, b|
        return false if bound <= {a, b}.max
      end
      true
    end

    # TODO
    def trim!(bound_shape) : self
      dims = @shape.size

      if bound_shape.size != dims
        raise DimensionError.new("invalid error :)")
      end

      bound_shape.each_with_index do |container_size, axis|
        @start[axis], @step[axis], @stop[axis], @shape[axis] =
          IndexRegion.trim_axis(container_size, @start[axis], @step[axis], @stop[axis], @shape[axis])
      end
      self
    end

    def reverse! : IndexRegion(T)
      @start, @stop = @stop, @start
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
        @start[axis] += amount
        @stop[axis] += amount
      end
      self
    end

    def translate(by offset : Enumerable) : self
      self.clone.translate!(offset)
    end

    # Gives an iterator over tuples {start[i], step[i], stop[i], shape[i]}
    def range_tuples
      @start.zip(@step, @stop, @shape)
    end

    def to_s(io)
      io << @degeneracy.map_with_index do |degen, i|
        if degen
          @start[i]
        elsif @step[i].abs == 1
          @start[i]..@stop[i]
        else
          @start[i]..@step[i]..@stop[i]
        end
      end
    end

    # TODO: in general, maybe use immediate methods rather than zip?
    def local_to_absolute(coord)
      coord.zip(@start, @step).map do |idx, start, step|
        start + idx * step
      end
    end

    def absolute_to_local(coord)
      coord.zip(@start, @step).map do |idx, start, step|
        (idx - start) // step
      end
    end

    def each(iter = LexIterator) : CoordIterator(T)
      LexIterator.new(self)
    end

    # =========== Range Canonicalization Helper Methods ====================
    
    protected def self.ensure_nonnegative(*range_literal : Int?)
      range_literal.each do |int|
        next if int.nil?
        if int < 0
          raise IndexError.new("Negative indices have no meaning when a bounding shape is not provided.")
        end
      end
    end

    protected def self.ensure_nonnegative(range_literal : Range)
      case first = range_literal.begin
      when Int
        self.ensure_nonnegative(first, range_literal.end)
      when Range
        self.ensure_nonnegative(first.begin, range_literal.end)
      end
    end

    protected def self.bounded?(range_literal : Int)
      true
    end

    def self.bounded?(range_literal : Range)
      case first = range_literal.begin
      when Int
        return false if range_literal.end.nil?
      when Range
        if first.end >= 0 && range_literal.end.nil?
          return false
        elsif first.begin.nil?
          return false
        end
      end
      true
    end

    protected def self.get_size(start, stop, step)
      if stop != start && step.sign != (stop <=> start)
        raise IndexError.new("Could not get size of range - step direction disagrees with start and stop.")
        return 0
        # done the painful way in case start and stop are unsigned
      elsif stop >= start
        return (stop - start) // step + 1
      else
        return (start - stop) // (-step) + 1
      end
    end

    protected def self.trim_axis(new_bound, start, step, stop, size)
      if start >= new_bound
        if stop >= new_bound # both out of bounds
          return {0, 0, 0, 0}
        elsif step < 0 # We started too high, but terminate inside the bounds
          span = (new_bound - 1) - stop
          size = span // step.abs + 1
          span -= span % step.abs

          return {stop + span, step, stop, size}
        end
      elsif step > 0 && stop >= new_bound # start in bounds, increase past bound
        span = (new_bound - 1) - start
        span -= span % step.abs
        size = span // step.abs + 1

        return {start, step, start + span, size}
      end
      {start, step, stop, size}
    end

    protected def self.infer_range(range : Range, step, bound)
      infer_range(bound, range.begin, range.end, range.excludes_end?, step)
    end

    protected def self.infer_range(range : Range, bound)
      first = range.begin
      case first
      when Range
        # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
        return infer_range(bound, first.begin, range.end, range.excludes_end?, first.end)
      else
        return infer_range(bound, first, range.end, range.excludes_end?)
      end
    end

    protected def self.infer_range(index : Int, bound)
      canonical = CoordUtil.canonicalize_index_unsafe(index, bound)
      {canonical, 1, canonical, 1}
    end

    protected def self.infer_range(bound : T, start : T?, stop : T?, exclusive : Bool, step : Int32? = nil) : Tuple(T, Int32, T, T) forall T
      # Infer endpoints
      if !step
        start = start ? CoordUtil.canonicalize_index_unsafe(start, bound) : T.zero
        temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : bound - 1

        step = (temp_stop >= start) ? 1 : -1
      else
        start = start ? CoordUtil.canonicalize_index_unsafe(start, bound) : (step > 0 ? T.zero : bound - 1)
        temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : (step > 0 ? bound - 1 : T.zero)
      end

      # Account for exclusivity
      if stop && exclusive
        if temp_stop == start
          # Range spans no integers; we use the convention start, stop, step, size = 0 to indicate this
          return {0, 0, 0, 0}
        end
        temp_stop -= step.sign
      end

      # Until now we haven't raised errors for invalid endpoints, because it was possible
      # that exclusivity would allow seemingly invalid endpoints (e.g., -6 is a valid exclusive
      # endpoint for bound=5, but not a valid *inclusive* one). We have to catch the case
      # where the range wasn't even valid here.
      if start < 0 || temp_stop < 0
        raise IndexError.new("Invalid index: At least one endpoint of #{start..stop} is negative after canonicalization.")
      end

      begin
        # Align temp_stop to an integer number of steps from start
        size = get_size(start, temp_stop, step)
        stop = start + (size - 1) * step

        return {start, step.to_i32, stop, size}
      rescue ex : IndexError
        # This doesn't change any functionality, but makes debugging easier
        raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(start, stop, exclusive)} and provided step #{step}")
      end
    end

    protected def self.range_valid?(start, stop, bound)
      return stop.in?(0...bound) && start.in?(0...bound)
    end

    # canonicalize_range(range, bound)
    # infer_range(range, bound)
    # all hte other stuff
    protected def self.canonicalize_range(range, bound : T) : Tuple(T, Int32, T, T) forall T
      start, step, stop, size = infer_range(range, bound)
      unless range_valid?(start, stop, bound)
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range for axis of length #{bound}.")
      end
      return {start, step.to_i32, stop, size}
    end
  end
end
