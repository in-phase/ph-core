module Lattice

    # for action items:
    # Make CoordIterator take a non-canonical region

    struct IndexRegion(T)
        
        
        
    end

    huge_narr
    huge_narr.each # error
    
    huge_narr[4.., 4..]

    # reusing endless regions can be done with Array(Range)
    # reusing an IndexRegion works 

    narr[region : Region]
    narr[region : Array(SteppedRange)]

    narr : 5x5
    narr2 : 3x3

    region = IndexRegion.new([0..-1, 0..-1], narr.shape)

    narr[region]
    narr2[region]

    # if optional stop:
    # - when taking region of bounded MI, restrict
    # - when making a CoordIterator
    
    struct Region(T)

        start = [1,2,3]
        stop = [6,7,8]
        step = [3,3,3]
        shape = [10,10,10]

        puts Region.new(start.dup, stop.dup, step.dup, shape.dup, ranges.dup)

        start = [nil, nil, nil]
        puts Region.new(start.dup, stop.dup, step.dup, shape.dup, ranges.dup)

        @start : Array(T) | Array(T?) | Array(Nil)
        @stop : Array(T) | Array(T?) | Array(Nil)

        @exclusive : Array(Bool)

        # Consider making @step a different type; @start, @stop, @shape must all be valid index representers but @step need not be (e.g. may be negative)
        @step : Array(T) | Array(T?) | Array(Nil)
        @shape : 
        

        def parse_range(input_start, input_stop, input_step, exclusive) 


        end



        # def self.new(region, shape : Indexable(T)) forall T
        # end
        # def self.new(start, stop, step, shape)
        #     new(start.dup, stop.dup, step.dup, shape.dup)
        # end

        
        protected def initialize(@start, @stop, @step)
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


        # like trim, but throws an error if it's out of bounds
        def verify(shape)
        end

        
        def trim(shape)
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
                    return {temp_stop, start, 0, 0} # DISCUSS: what did we decide here? Do we allow the empty range? I left our previous error in below
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