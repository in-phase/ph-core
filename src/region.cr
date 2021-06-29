module Lattice

    struct Region(T)

        @start : Array(T)
        @stop : Array(T)

        # Consider making @step a different type; @start, @stop, @shape must all be valid index representers but @step need not be (e.g. may be negative)
        @step : Array(T)
        @shape : Array(T)

        def self.new(region, shape : Indexable(T)) forall T
        end

        
        protected def initialize(@first, @last, @step)
        end


        # def self.new(range : Range, step, bound)
        #     canonicalize(range.begin, range.end, range.excludes_end?, bound, step)
        #   end
      
        #   def self.new(range : SteppedRange, bound)
        #     canonicalize(range.begin, range.end, false, bound, range.step)
        #   end
      
        #   def self.new(range : Range, bound)
        #     first = range.begin
        #     case first
        #     when Range
        #       # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
        #       return canonicalize(first.begin, range.end, range.excludes_end?, bound, first.end)
        #     else
        #       return canonicalize(first, range.end, range.excludes_end?, bound)
        #     end
        # end


        protected def self.canonicalize_range(range : Range, step, bound)
            infer_range(bound, range.begin, range.end, range.excludes_end?, step)
        end

        protected def self.canonicalize_range(range : Range, bound)
            first = range.begin 
            case first
            when Range 
                # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
                return infer_range(bound, first.begin, range.end, range.excludes_end?, first.end)
            else
                return infer_range(bound, first, range.end, range.excludes_end?)
            end
        end

        protected def self.canonicalize_range(index : Int, bound)
            canonical = CoordUtil.canonicalize_index_unsafe(index, bound)
            {canonical, canonical, 1, 1}
        end


        # StepIterator behaviour:
        # (a...a).step(b), b anything => allowed, does nothing
        # (4..2).step(7) (i.e., wrong step direction)=> allowed, does nothing
        # (a..b).step(0) => ArgumentError (i.e., any range that *should* iterate elements but can't because step=0)

        protected def self.infer_range(bound : T, start : T?, stop : T?, exclusive : Bool, step=nil) forall T

            if !step
                start = start ? CoordUtil.canonicalize_index(start, bound) : T.zero
                temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : bound - 1

                step = (temp_stop >= start) ? 1 : -1
            else 
                start = start ? CoordUtil.canonicalize_index(start, bound) : (step > 0 ? 0 : bound - 1)
                temp_stop = stop ? CoordUtil.canonicalize_index_unsafe(stop, bound) : (step > 0 ? bound - 1 : 0)

                if temp_stop != start && temp_stop <=> start != step.sign
                    raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(start, stop, exclusive)} and provided step #{step}")
                end
            end

            if stop && exclusive
                if temp_stop == start
                    return {0,0,0,0} # DISCUSS: what did we decide here? Do we allow the empty range? I left our previous error in below
                    # raise IndexError.new("Could not canonicalize range: #{Range.new(start, stop, exclusive)} does not span any integers.")
                end
                temp_stop -= step.sign
            end

        end

        protected def infer_region(region, shape : Indexable(T)) forall T

            # Allocate the full region to start
            @first = [T.zero] * shape.size 
            @step = [T.zero + 1] * shape.size
            @last = shape.dup



            # Here, handle:
            # - exclusivity
            # - inferred end points
            # - inferred step sizes

            # In constructor, handle:
            # - aligning start to stop 
            # - checking that start, stop are in range for shape





        end
    end
end