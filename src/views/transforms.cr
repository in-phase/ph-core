
# needed only for RegionTransform
require "../n_dim/region_helpers"

module Lattice

    # probably done
    abstract struct CoordTransform
        @@commutes = [] of CoordTransform.class
        
        def compose(t : CoordTransform) : CoordTransform
            return ComposedTransform[self, t]
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

    # probably done for now
    struct ComposedTransform < CoordTransform
        @transforms : Array(CoordTransform)

        def initialize(@transforms = [] of CoordTransform)
        end
        
        def self.[](*transforms)
            new (transforms.map &.as(CoordTransform)).to_a
        end

        def clone
            # TODO: decide if this needs to be clone (we will have to define a clone method on all transforms then)
            ComposedTransform.new(@transforms.dup)
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
            # NOTE: if we ever add a PadTransform, this could break. If a PadTransform encounters a coord outside the src, it should return a default/computed value early.
            transforms.reverse.reduce(coord) {|coord, trans| trans.apply(coord)}
        end

        # TODO: see clone
        def transforms
            @transforms.dup
        end

        protected def transforms!
            @transforms
        end
    end


   
    # done
    struct NoTransform < CoordTransform
        def compose(t : CoordTransform) : CoordTransform
            t
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            coord
        end
    end

    # probably done
    struct ReshapeTransform < CoordTransform

        @new_shape : Array(Int32)
        @src_shape : Array(Int32)

        def initialize(@src_shape, @new_shape)
        end

        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                # Always yield to the latest 'reshape' call in a chain
                return t
            else
                return super
            end
        end

        # TODO: these three methods were stolen from NArray. Move to somewhere more mutually useful?
        # Also TODO: brainstorm if there is a faster algorithm for doing this directly, without an intermediate index
        protected def index_to_coord(index, shape)
            coord = Array(Int32).new(shape.size, 0)
            shape.reverse.each_with_index do |length, dim|
                coord[dim] = index % length
                index //= length
            end
            coord.reverse
        end

        protected def coord_to_index(coord, shape) : Int32
            axis_strides = axis_strides(shape)
            index = 0
            coord.each_with_index do |elem, idx|
                index += elem * axis_strides[idx]
            end
            index
        end

        protected def axis_strides(shape)
            ret = shape.clone
            ret[-1] = 1
      
            ((ret.size - 2)..0).step(-1) do |idx|
              ret[idx] = ret[idx + 1] * shape[idx + 1]
            end
      
            ret
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            index = coord_to_index(coord, @new_shape)
            src_coord = index_to_coord(index, @src_shape)
            src_coord
        end
    end

    struct RegionTransform < CoordTransform

        @region : Array(RegionHelpers::SteppedRange)

        def initialize(@region)
        end

        # TODO
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
            @region.map_with_index { |range, dim| range.local_to_absolute(coord[dim]) }
        end
    end

    struct TransposeTransform < CoordTransform

        # TODO
        def compose(t : CoordTransform) : CoordTransform
            case t
            when self
                return NoTransform.new
            else
                return super
            end
        end

        def apply(coord : Array(Int32)) : Array(Int32)
            coord.reverse
        end
    end

    struct ReverseTransform < CoordTransform

        @shape : Array(Int32)

        def initialize(@shape)
        end

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
            coord.map_with_index do |el, i|
                @shape[i] - 1 - el
            end
        end
    end


    # OG
    # 1 2 3
    # 4 5 6
    # 7 8 9
    # 10 11 12

    # reshaped
    # 1 2 3 4 5 6 
    # 7 8 9 10 11 12

    # reversed
    # 12 11 10
    # 9 8 7
    # 6 5 4
    # 3 2 1

    # transposed
    # 1 4 7 10
    # 2 5 8 11
    # 3 6 9 12

    # region
    # 2 3
    # 8 9

    region = RegionHelpers.canonicalize_region([0..2..2, 1..], [4,3])

    tran = TransposeTransform.new
    rev = ReverseTransform.new([4,3])
    res = ReshapeTransform.new([4,3], [2, 6])
    reg = RegionTransform.new(region)


    puts tran.apply([1,2])
    puts res.apply([1,3])
    puts rev.apply([0,2])
    puts reg.apply([0, 1])

    puts rev.compose(tran)
    puts tran.compose(tran)
end


