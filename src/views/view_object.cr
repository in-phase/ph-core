require "../lattice"

module Lattice

    # Views, like any MultiIndexable, may be iterated over in an arbitrarily defined order; however, 
    # they can only be stored internally as one of the 4 primary orders (Lex, Colex, RevLex, RevColex)
    # as (barring contrived edge cases) these seem to be the only orderings that make sense for 
    # a MultiIndexable structure.

    module ViewObject(B,T,R)

        # B: Base (type of source array; should be a MultiIndexable(T), but we couldn't find a good way to find that automatically?)
        # T: Type (stored)
        # R: Return type

        include MultiIndexable(R)

        getter src : B
        getter region : Array(RegionHelpers::SteppedRange)
        @is_colex : Bool

        @shape : Array(Int32)
        getter size : Int32
        
        abstract def view(region, order : Order)
        abstract def clone
        
        # For use externally
        def shape : Array(Int32)
            @shape.dup
        end

        def view(*region)
            view(region, order: Order::LEX)
        end

        def transpose!
            @is_colex = !@is_colex
            @shape = @shape.reverse
            self
        end

        def reverse!
            @region.map! &.reverse
            self
        end

        def reverse
            clone.reverse!
        end

        def transpose
            clone.transpose!
        end

        protected def self.parse_region(region, src, reverse : Bool) : Array(RegionHelpers::SteppedRange)
            new_region = region ? RegionHelpers.canonicalize_region(region, src.shape) : RegionHelpers.full_region(src.shape)
            new_region.map! &.reverse if reverse
            new_region
        end

        protected def parse_and_convert_region(region, reverse : Bool) : Array(RegionHelpers::SteppedRange)
            new_region = local_region_to_srcframe(RegionHelpers.canonicalize_region(region, shape))
            new_region.map! &.reverse if reverse
            new_region
        end

        protected def local_coord_to_srcframe(coord) : Array(Int32)
            coord = coord.reverse if @is_colex
            new_coord = @region.map_with_index { |range, dim| range.local_to_absolute(coord[dim]) }
        end

        protected def local_region_to_srcframe(region) : Array(RegionHelpers::SteppedRange)
            region = region.reverse if @is_colex
            new_region = @region.map_with_index { |range, dim| range.compose(region[dim])}
        end

    end

end