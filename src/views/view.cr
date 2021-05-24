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
    class View(S, T)
        include MultiIndexable(T)
        include MultiWritable(T)

        # A proc that transforms one coordinate into another coordinate.
        @src : S
        @transform : ComposedTransform
        @shape : Array(Int32)

        protected def self.new(src : S, transform : ComposedTransform = ComposedTransform.new)
            new(src, src.shape, transform)
        end

        protected def initialize(@src : S, @shape : Array(Int32), @transform = ComposedTransform.new)
        end

        # def initialize(@src : S, region)
        #     self.of(@src, region)
        # end

        def self.of(src : S, region = nil) : self
            if src.is_a?(View) 
                return src.view(region)
            else
                new_view = View(S, typeof(src.sample)).new(src)
                new_view.restrict_to(region) if region
            end
            new_view
        end

        def clone : self
            View(S,T).new(@src, @shape, @transform.clone)
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

        def transpose! : self
            @shape = @shape.reverse
            @transform.compose!(TransposeTransform.new)
            self
        end

        def transpose : self
            clone.transpose!
        end

        def reverse! : self
            @transform.compose!(ReverseTransform.new(@shape))
            self
        end

        def reverse : self
            clone.reverse!
        end

        def unsafe_fetch_element(coord) : T
            @src.unsafe_fetch_element(@transform.apply(coord))
        end

        def unsafe_fetch_region(region) : self
            view(region)
        end

        macro ensure_writable
            {% unless S < MultiWritable %}
                {% raise "Could not write to #{@type}: #{B} is not a MultiWritable." %}
            {% end %}
        end

        def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))
            ensure_writable
            view(region).set(value)
            # the below will probably not work since we may not get a pretty region out of our transform chain.
            # instead: iterate over region and replace each value
            # @src.unsafe_set_region(local_region_to_srcframe(region), src)
            # TODO: get a useful each_in_region going in multiindexable; will save a couple computation steps compared to current implementation
        end

        def unsafe_set_region(region : Enumerable, value : T)
            ensure_writable
            view(region).set(value)
            # TODO: get a useful each_in_region going in multiindexable; will save a couple computation steps compared to current implementation
        end

        # sets all elements in this view 
        protected def set(src : MultiIndexable(T))
            # TODO: perform relevant size/shape checks and replace src[coord] with src.unsafe_fetch_element(coord)
            ensure_writable
            each_with_coord {|el, coord| @src.unsafe_set_element(@transform.apply(coord), src[coord])} 
        end

        # sets all elements in this view
        protected def set(value : T)
            ensure_writable
            each_with_coord {|el, coord| @src.unsafe_set_element(@transform.apply(coord), value)}
        end

        # def process : ProcView
        # end

        def to_narr : NArray(T)
            iter = self.each
            NArray(T).build(@shape) {|coord,i| unsafe_fetch_element(coord)}
        end
    end

    narr = NArray.build([2,4,3]) {|c,i| i}
    puts narr
    view = View.of(narr, [..., 1..2])
    view =  view.view([0,.., ..2..])
    puts view.reshape!([4])
    puts view.transpose! # NOTE: should "transpose" work for 1D?

    view2 = View.of(narr, [.., 1..2])
    puts view2
    puts view2.transpose!
    puts view2.reshape!([4,3])


    view2[1..2..,1..] = -3 #NArray.new([[-1,-2],[-3,-4]])
    puts view2

    puts narr
    puts view2
    narr[0, ..1] = -5
    narr.unsafe_set_element([1,1,0], 100)
    # view2 = 
    puts view2

    

end


