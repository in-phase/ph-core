module Lattice

    # NOTE: We talked about types not composing with each other. I forgot that reverse and region compose well. It probably is useful to worry about these cases
    # since reverse and region don't commute; so chains of reverse/region could stack up.

    # unlike commutes composes should be strictly one-way. The algorithm for Reverse.compose(Region) is different (much easier) from Region.compose(Reverse).
    # If we have [A,B] and add C:
    # try C(B). else:
    # if B commutes C:
    #     try B(C)
    # else
    #     break
    # end    
    # then repeat for A and C

    # alternatively: just make Reverse a type of Region, not its own transform?
    # - no longer commutative with reshape
    # - resolves issues of one-way composability

    # compile time

    abstract struct Transform

        # make this constant? Class variable?
        COMMUTES = [] of Transform.class
        COMPOSES = false
        
        # currently: use a NoTransform as a special return type?
        # alternatively, since we are already checking whether it composes - use Nil to indicate annhiliation?
        def compose?(t : Transform) : Transform?
            return nil
        end
        
        def commutes_with?(t : Transform) : Bool
            return commutes.any? {|type| type == t.class} || t.commutes.any? {|type| type == self.class}
        end

        protected def commutes
            {% begin %}{{@type.id}}::COMMUTES{% end %}
        end

        def composes? : Bool
            {% begin %}{{@type.id}}::COMPOSES{% end %}
        end

        abstract def apply(coord : Array(Int32)) : Array(Int32)
    end

    struct NoTransform < Transform
        COMMUTES = [ReverseTransform, ReshapeTransform, RegionTransform, TransposeTransform]
        COMPOSES = true

        def compose? : Transform?
            NoTransform.new
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            coord
        end
    end

    struct ReshapeTransform < Transform

        COMMUTES = [NoTransform, ReverseTransform]
        COMPOSES = true

        @new_shape : Array(Int32)
        @src_shape : Array(Int32)

        def initialize(@src_shape, @new_shape)
        end

        # Newer calls to reshape in a chain overwrite previous calls.
        def compose?(t : Transform) : Transform?
            return self
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            # TODO: 
            # coord -> index in @new_shape
            # index -> coord in @old_shape
            raise NotImplementedError.new
            coord
        end
    end

    struct RegionTransform < Transform

        def compose?(t : Transform) : Transform?
            case t
            when self
                # compose regions
            when ReverseTransform
            end
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            local_coord_to_srcframe(coord)
        end

        protected def local_coord_to_srcframe(coord) : Array(Int32)
            new_coord = @region.map_with_index { |range, dim| range.local_to_absolute(coord[dim]) }
        end

        protected def local_region_to_srcframe(region) : Array(RegionHelpers::SteppedRange)
            region = region.reverse if @is_colex
            new_region = @region.map_with_index { |range, dim| range.compose(region[dim])}
        end
    end

    # becomes COLEX
    struct TransposeTransform < Transform
        COMPOSES = true
        COMMUTES = [ReverseTransform]

        def compose?(t : self) : Transform?
            NoTransform.new
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            raise NotImplementedError.new
            coord
        end
    end

    struct ReverseTransform < Transform
        COMPOSES = true
        COMMUTES = [TransposeTransform, ReshapeTransform]

        def compose?(t : Transform) : Transform?
            case t
            when self
                return NoTransform.new
            # when RegionTransform
            #     region = t.region.each do |range|
            #         range.reverse
            #     end
            #     return RegionTransform.new(region)
            else 
                nil
            end
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            raise NotImplementedError.new
            coord
        end
    end

    tran = TransposeTransform.new
    rev = ReverseTransform.new
    res = ReshapeTransform.new([3], [4])
    puts res.commutes_with?(tran)
    puts rev.commutes_with?(res)
    puts res.commutes_with?(rev)

    puts tran.composes?
    puts rev.compose?(tran)
end


