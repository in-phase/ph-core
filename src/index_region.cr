require "./coord_util"
require "./multi_indexable"
require "./type_aliases"
require "./stepped_range"
require "./region_util"

module Lattice

    struct IndexRegion(T)
        # DISCUSS: should it be a MultiIndexable?
        # should .each give an iterator over dimensions, or over coords?
        # include MultiIndexable(Array(T))

        protected getter start : Array(T)
        protected getter stop : Array(T)

        # @start, @stop, @shape must all be valid index representers but @step need not be (e.g. may be negative)
        # TODO: see if there is a way to generalize to any SignedInt
        protected getter step : Array(Int32)
        @shape : Array(T)

        # =========== Testing garbage ==========================================

        region = IndexRegion.new([1..3, 5...1, -3...-2..], [7,7,7,7])
        puts region
        puts region.unsafe_fetch_chunk(IndexRegion.new([1,1,1,1], region.shape))
        region.range_tuples.each {|x| puts x}
        puts region.in?([2,2,2,2])


        # =========================== Constructors ==============================

        # Possibly?????????? Define a canonical region independent of bounds - ONLY if:
        # - all integers are positive
        # - all start/stops are explicit, not inferred
        # def self.new(region_literal)
        # end

        # 
        def self.new(region : IndexRegion(T), bound_shape)
            if in?(bound_shape)
                return region.clone 
            end
            raise IndexError.new("Region #{region} does not fit inside #{bound_shape}")
        end

        # Main constructor
        def self.new(region_literal, bound_shape : Indexable(T)) : IndexRegion(T)
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
            @start = [T.zero] * bound_shape.size 
            @step = [T.zero + 1] * bound_shape.size
            @stop = bound_shape.map &.pred
            @shape = bound_shape.dup
        end

        protected def initialize(@start, @step, @stop, @shape)
        end

        # ============= Methods required by MultiIndexable ===========================

        def shape 
            @shape.dup
        end

        def shape_internal 
            @shape
        end

        # composes regions
        def unsafe_fetch_chunk(region : IndexRegion) : IndexRegion(T)
            new_start = local_to_abslute(region.start)
            new_stop = local_to_abslute(region.stop)
            
            new_step = @step.zip(region.step).map do |outer, inner|
                outer * inner
            end
            IndexRegion(T).new(new_start, new_step, new_stop, region.shape)
        end

        # gets absolute coordinate of a coord in the region's local reference frame
        def unsafe_fetch_element(coord : Coord) : Array(T)
            local_to_abslute(coord)
        end

        # ========================== Other =====================================

        def clone : IndexRegion(T)
            IndexRegion(T).new(@start.clone, @step.clone, @stop.clone, @shape.clone)
        end

        # TODO: check dimensions
        def in?(bound_shape) : Bool
            bound_shape.zip(@start, @stop).each do |bound, a, b|
                return false if bound <= {a,b}.max
            end
            return true
        end

        # TODO
        def trim(bound_shape) : IndexRegion(T)
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

        def local_to_abslute(coord)
            coord.zip(@start, @step).map do |idx, start, step|
                start + idx * step
            end
        end

        # =========== Range Canonicalization Helper Methods ====================

        protected def self.get_size(start, stop, step, raises : Bool = true, msg="")
            if stop != step && step.sign != (stop <=> start)
                if raises
                    raise IndexError.new(msg)
                end
                return 0
            # done the painful way in case start and stop are unsigned
            elsif stop >= start
                return (stop - start) // step + 1
            else
                return (start - stop) // (-step) + 1
            end
        end

        protected def self.canonicalize_range(range : Range, step, bound)
            infer_range(bound, range.begin, range.end, range.excludes_end?, step)
        end

        protected def self.canonicalize_range(range : Range, bound)
            first = range.begin 
            case first
            when Range 
                # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
                return canonicalize_range(bound, first.begin, range.end, range.excludes_end?, first.end)
            else
                return canonicalize_range(bound, first, range.end, range.excludes_end?)
            end
        end

        protected def self.canonicalize_range(index : Int, bound)
            canonical = CoordUtil.canonicalize_index(index, bound)
            {canonical, canonical, 1, 1}
        end

        protected def self.canonicalize_range(bound : T, start : T?, stop : T?, exclusive : Bool, step : Int32? = nil) : Tuple(T, Int32, T, T) forall T 
            # Infer endpoints
            if !step
                start = start ? CoordUtil.canonicalize_index(start, bound) : T.zero
                temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : bound - 1

                step = (temp_stop >= start) ? 1 : -1
            else 
                start     = start ? CoordUtil.canonicalize_index(start, bound)       : (step > 0 ? T.zero : bound - 1)
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

            # Align temp_stop to an integer number of steps from start
            conflict_msg = "Could not canonicalize range: Conflict between implicit direction of #{Range.new(start, stop, exclusive)} and provided step #{step}"
            size = get_size(start, temp_stop, step, msg: conflict_msg)
            stop = start + (size - 1) * step

            # check if stop is still in range
            if stop < 0 || stop >= bound
                raise IndexError.new("Could not canonicalize range: #{Range.new(start, stop, exclusive)} is not a sensible index range for axis of length #{bound}.")
            end

            puts size
            return {start, step.to_i32, stop, size}
        end
    end
end