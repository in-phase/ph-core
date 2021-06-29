require "./coord_util"
require "./multi_indexable"
require "./type_aliases"
require "./stepped_range"
require "./region_util"

module Lattice

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

        # =========== Testing garbage ==========================================

        # region = IndexRegion.new([1..3, 5...1, -3...-2..], [7,7,7,7])
        # puts region
        # puts region.unsafe_fetch_chunk(IndexRegion.new([1,1,1,1], region.shape))
        # region.range_tuples.each {|x| puts x}
        # puts region.in?([2,2,2,2])



        # =========================== Constructors ==============================

        # Possibly?????????? Define a canonical region independent of bounds - ONLY if:
        # - all integers are positive
        # - all start/stops are explicit, not inferred
        # def self.new(region_literal)
        # end

        # 
        def self.new(region : IndexRegion(T), bound_shape)
            if region.fits_in?(bound_shape)
                return region.clone 
            end
            raise IndexError.new("Region #{region} does not fit inside #{bound_shape}")
        end

        def self.new(region_literal : Enumerable, *, trim_to : Indexable(T))
            idx_r = new(bound_shape)
            region_literal.each_with_index do |range, i|
                idx_r.start[i], idx_r.step[i], idx_r.stop[i], idx_r.shape_internal[i] = infer_range(range, bound_shape[i])
            end
            idx_r.trim!(trim_to)
        end

        # Main constructor
        def self.new(region_literal : Enumerable, bound_shape : Indexable(T)) : IndexRegion(T)
            idx_r = new(bound_shape)
            region_literal.each_with_index do |range, i|
                idx_r.start[i], idx_r.step[i], idx_r.stop[i], idx_r.shape_internal[i] = canonicalize_range(range, bound_shape[i])
            end
            idx_r
        end

        # Gets the region including all coordinates in the given bound_shape
        def self.cover(bound_shape : Indexable(T))
            new(bound_shape)
        end

        def initialize(@start, step=nil, *, @stop : Indexable(T))
            if !step
                step = start.map_with_index {|s, i| stop[i] <=> s}
            end
            @step = step
            @shape = [] of T # initialized first to pacify the compiler, which 
            # (I think) is unable to detect the output of self.get_size
            @shape = start.zip(stop, step).map {|vals| self.get_size(*vals)}
        end

        def initialize(@start, step=nil, *, @shape : Indexable(T))
            if !step
                step = start.map_with_index {|s, i| stop[i] <=> s}
            end
            @step = step
            @stop = start.zip(step, shape).map {|x0, dx, size| x0 + dx * size}
        end

        protected def initialize(bound_shape : Indexable(T))
            @start = Array.new(bound_shape.size, T.zero) 
            @step = Array.new(bound_shape.size, T.zero + 1)
            @stop = bound_shape.map &.pred
            @shape = bound_shape.dup
        end

        protected def initialize(@start, @step, @stop, @shape)
        end

        # ============= Methods required by MultiIndexable ===========================
        def shape : Array(T)
            @shape.dup
        end

        def shape_internal 
            @shape
        end

        def size 
            @shape.product 
        end

        # composes regions
        def unsafe_fetch_chunk(region : IndexRegion) : IndexRegion(T)
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

        def clone : IndexRegion(T)
            IndexRegion(T).new(@start.clone, @step.clone, @stop.clone, @shape.clone)
        end

        # TODO: check dimensions
        def fits_in?(bound_shape) : Bool
            bound_shape.zip(@start, @stop).each do |bound, a, b|
                return false if bound <= {a,b}.max
            end
            return true
        end

        # TODO
        def trim!(bound_shape) : IndexRegion(T)
            dims = @shape.size
            
            if bound_shape.size != dims
                raise DimensionError.new("invalid error :)")
            end

            bound_shape.each_with_index do |container_size, axis|
                @start[axis], @step[axis], @stop[axis], @shape[axis] =
                    self.trim_axis(container_size, @start[axis], @step[axis], @stop[axis], @shape[axis])
            end

            self
        end

        def trim(bound_shape) : IndexRegion(T)
            self.clone.trim!(bound_shape)
        end

        def translate!(by offset : Enumerable) : IndexRegion(T)
            offset.each_with_index do |amount, axis|
                @start[axis] += amount
                @stop[axis] += amount
            end
        end

        def translate(by offset : Enumerable) : IndexRegion(T)
            self.clone.translate!(offset)
        end

        # Gives an iterator over tuples {start[i], step[i], stop[i], shape[i]}
        def range_tuples
            @start.zip(@step, @stop, @shape)
        end

        def inspect(io)
            # Let the 
            io <<  @shape.map_with_index do |size, i|
                if size == 1
                    next @start[i]
                elsif @step[i].abs == 1
                    next @start[i]..@stop[i]
                else
                    next @start[i]..@step[i]..@stop[i]
                end
            end
        end

        # TODO: in general, maybe use immediate methods rather than zip?
        def local_to_absolute(coord)
            coord.zip(@start, @step).map do |idx, start, step|
                start + idx * step
            end
        end

        def each(iter = LexIterator) : Iterator(T)
            LexIterator.new(self)
        end

        # =========== Range Canonicalization Helper Methods ====================

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
                    return {0,0,0,0}
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
            canonical = CoordUtil.canonicalize_index(index, bound)
            {canonical, canonical, 1, 1}
        end

        protected def self.infer_range(bound : T, start : T?, stop : T?, exclusive : Bool, step : Int32? = nil) : Tuple(T, Int32, T, T) forall T 
            # Infer endpoints
            if !step
                start = start ? CoordUtil.canonicalize_index_unsafe(start, bound) : T.zero
                temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : bound - 1

                step = (temp_stop >= start) ? 1 : -1
            else 
                start     = start ? CoordUtil.canonicalize_index_unsafe(start, bound)       : (step > 0 ? T.zero : bound - 1)
                temp_stop = stop  ? CoordUtil.canonicalize_index_unsafe(stop, bound) : (step > 0 ? bound - 1 : T.zero)
            end

            # Account for exclusivity
            if stop && exclusive
                if temp_stop == start
                    # Range spans no integers; we use the convention start, stop, step, size = 0 to indicate this
                    return {0,0,0,0}
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