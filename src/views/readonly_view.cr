require "../n_dim/*"
require "./transforms"
require "../n_array"
# for testing/display
require "../n_dim/formatter"


# our framework:
# View(B,T)
#   => coord_transforms: [] of Proc(Array(Int32), Array(Int32))

# ProcView(B,T,R)
#   @view : View(B,T)
#   => elem_transforms @proc : Proc(T,R)
  
#   forward_missing_to @view

module Lattice
    class ReadonlyView(S, R)
        include MultiIndexable(R)

        # A proc that transforms one coordinate into another coordinate.
        @src : S
        @transform : ComposedTransform
        @shape : Array(Int32)

        def self.of(src : S, region = nil) : self
            case src
            when ReadonlyView
                return src.view(region)
            else
                new_view = ReadonlyView(S, typeof(src.sample)).new(src)
                new_view.restrict_to(region) if region
                return new_view
            end
        end

        protected def initialize(@src : S, @transform : ComposedTransform = ComposedTransform.new)
            @shape = @src.shape
        end

        protected def initialize(@src : S, @shape : Array(Int32), @transform = ComposedTransform.new)
        end

        # def initialize(@src : S, region)
        #     self.of(@src, region)
        # end

        def clone : self
            typeof(self).new(@src, @shape.clone, @transform.clone)
        end

        def shape : Array(Int32)
            @shape.clone
        end

        def view(region = nil) : self
            new_view = clone
            new_view.restrict_to(region) if region
            new_view
        end

        # an in-place version of view(region), because view! didn't make much sense
        protected def restrict_to(region) : self
            canonical = RegionHelpers.canonicalize_region(region, @shape)
            @shape = RegionHelpers.measure_canonical_region(canonical)
            @transform.compose!(RegionTransform.new(canonical))
            self
        end

        def reshape!(new_shape) : self
            # TODO:
            # check if number of elements is still valid
            @transform.compose!(ReshapeTransform.new(@shape, new_shape))
            @shape = new_shape
            self
        end

        def reshape(new_shape) : self
            clone.reshape!(new_shape)
        end

        def permute!(order : Enumerable? = nil) : self
            pt = PermuteTransform.new(order || self.dimensions)
            @shape = pt.permute(@shape)
            @transform.compose!(pt)
            self
        end

        def permute(order : Enumerable? = nil) : self
            clone.permute!(order)
        end

        def reverse! : self
            @transform.compose!(ReverseTransform.new(@shape))
            self
        end

        def reverse : self
            clone.reverse!
        end

        def unsafe_fetch_region(region) : self
            view(region)
        end

        def unsafe_fetch_element(coord) : R
            @src.unsafe_fetch_element(@transform.apply(coord)).unsafe_as(R)
        end

        def process(new_proc : (R -> U)) : ProcView(S, R, U) forall U
            ProcView(S, R, U).new(@src, @shape.clone, new_proc, @transform.clone)
        end

        def process(&block : (R -> U)) : ProcView(S, R, U) forall U
            process(block)
        end

        def to_narr : NArray
            iter = self.each
            NArray.build(@shape) {|coord,i| unsafe_fetch_element(coord)}
        end
    end
end


