module Lattice

    # NOTE: We talked about types not composing with each other. I forgot that reverse and region compose well. It probably is useful to worry about these cases
    # since reverse and region don't commute; so chains of reverse/region could stack up.


    # 
    # ReverseTransform -> RegionTransform 

    # 1 2 3
    # 4 5 6 
    # 7 8 9

    # 4 5
    # 7 8

    # 4 7
    # 5 8

    # RegionTransform, ColexTransform 
    # [1..2, 0..1]

    # ColexTransoform, RegionTransform [0..1, 1..2]

    # RegionTransofrm, ColexTransform, Region, Colex, Region, Colex


    # [A, B, C] B.compose(C) 
    # [A, C, B] 
    # unlike commutes composes should be strictly one-way. The algorithm for Reverse.compose(Region) is different (much easier) from Region.compose(Reverse).
    # If we have [A,B] and add C:
    # try C(B). else:
    # if B commutes C:
    #     try B(C)
    # else
    #     break
    # end    
    # then repeat for A and C

    # alternatively: just make Reverse a type of Region, not its own CoordTransform?
    # - no longer commutative with reshape
    # - resolves issues of one-way composability

    # compile time

    abstract struct CoordTransform
        @@commutes = [] of CoordTransform.class
        
        def compose(t : CoordTransform) : CoordTransform
            return ComposedTransform[t, self]
        end

        # Possibly
        # def commute?(t : CoordTransform) : Tuple(Transform, CoordTransform)
        # end

        def commutes_with?(t : CoordTransform) : Bool
            return commutes.any? {|type| type == t.class} || t.commutes.any? {|type| type == self.class}
        end

        protected def commutes
            @@commutes
        end

        abstract def apply(coord : Array(Int32)) : Array(Int32)
    end


    struct ComposedTransform < CoordTransform
        @transforms : Array(CoordTransform)

        def initialize(@transforms = [] of CoordTransform)
        end
        
        def self.[](*transforms)
            new (transforms.map &.as(CoordTransform)).to_a
        end

        def clone
            ComposedTransform.new(@transforms.clone)
        end

        def compose!(t : CoordTransform)
            @transforms << t
        end

        # stolen from our attempt at View class
        # def push_transform(t : Transform) : Nil
        #     if t.composes?
        #         (@transforms.size - 1).downto(0) do |i|
        #             if new_transform = t.compose?(@transforms[i])
        #                 if new_transform < NoTransform # If composition => annihiliation
        #                     @transforms.delete_at(i)
        #                 else
        #                     @transforms[i] = new_transform
        #                 end
        #                 return
        #             elsif !t.commutes_with?(@transforms[i])
        #                 break
        #             end
        #         end
        #     end
        #     @transforms << t
        # end

        def compose!(t : ComposedTransform)
            @transforms += t
        end

        def compose(t : CoordTransform) : CoordTransform
            new_transform = clone
            new_transform.compose!(t)
        end

        def compose(t : CoordTransform) : ComposedTransform
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            transforms.reverse.reduce(coord) {|coord, trans| trans.apply(coord)}
        end

        def transforms
            @transforms.clone
        end

        protected def transforms!
            @transforms
        end
    end


   

    struct NoTransform < CoordTransform
        def compose(t : CoordTransform) : CoordTransform
            t
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            coord
        end
    end

    struct ReshapeTransform < CoordTransform

        @new_shape : Array(Int32)
        @src_shape : Array(Int32)

        def initialize(@src_shape, @new_shape)
        end

        # Newer calls to reshape in a chain overwrite previous calls.
        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                return self
            else
                return super
            end
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            # TODO: 
            # coord -> index in @new_shape
            # index -> coord in @old_shape
            raise NotImplementedError.new
            coord
        end
    end

    struct RegionTransform < CoordTransform

        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                # compose regions
            when ReverseTransform
            else
                return super
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
    struct TransposeTransform < CoordTransform

        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                return NoTransform.new
            else
                return super
            end
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            raise NotImplementedError.new
            coord
        end
    end

    struct ReverseTransform < CoordTransform

        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                return NoTransform.new
            # when RegionTransform
            #     region = t.region.each do |range|
            #         range.reverse
            #     end
            #     return RegionTransform.new(region)
            else 
                return super
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

    puts rev.compose(tran)
    puts tran.compose(tran)
end


