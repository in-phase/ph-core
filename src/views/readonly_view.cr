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
    class ReadonlyView(S, T, R)
        include MultiIndexable(R)

        # A proc that transforms one coordinate into another coordinate.
        @src : S
        @transform : ComposedTransform
        @shape : Array(Int32)

        protected def initialize(@src : S, @transform : ComposedTransform = ComposedTransform.new)
            @shape = @src.shape
        end

        protected def initialize(@src : S, @shape : Array(Int32), @transform = ComposedTransform.new)
        end

        # def initialize(@src : S, region)
        #     self.of(@src, region)
        # end

        def self.of(src : S, region = nil) : self
            if src.is_a?(ReadonlyView) 
                return src.view(region)
            else
                new_view = View(S, typeof(src.sample)).new(src)
                new_view.restrict_to(region) if region
            end
            new_view
        end

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

        def unsafe_fetch_element(coord) : R
            @src.unsafe_fetch_element(@transform.apply(coord))
        end

        def unsafe_fetch_region(region) : self
            view(region)
        end

        # def process : ProcView
        # end

        def to_narr : NArray(T)
            iter = self.each
            NArray(T).build(@shape) {|coord,i| unsafe_fetch_element(coord)}
        end
    end


end


