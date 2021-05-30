require "./readonly_view"

module Lattice
    class View(S, R) < ReadonlyView(S, R)
        include MultiWritable(R)

        def self.of(src : S, region = nil) : self
            case src
            when ReadonlyView
                return src.view(region)
            else
                new_view = View(S, typeof(src.sample)).new(src)
                new_view.restrict_to(region) if region
                return new_view
            end
        end

        # protected def initialize(@src : S, @transform : ComposedTransform = ComposedTransform.new)
        #     @shape = @src.shape
        # end

        # protected def initialize(@src : S, @shape : Array(Int32), @transform = ComposedTransform.new)
        # end

        macro ensure_writable
            {% unless S < MultiWritable %}
                {% raise "Could not write to #{@type}: #{S} is not a MultiWritable." %}
            {% end %}
        end

        def unsafe_set_region(region : Enumerable, src : MultiIndexable(R))
            ensure_writable
            view(region).set(src)
            # the below will probably not work since we may not get a pretty region out of our transform chain.
            # instead: iterate over region and replace each value
            # @src.unsafe_set_region(local_region_to_srcframe(region), src)
            # TODO: get a useful each_in_region going in multiindexable; will save a couple computation steps compared to current implementation
        end

        def unsafe_set_region(region : Enumerable, value : R)
            ensure_writable
            view(region).set(value)
            # TODO: get a useful each_in_region going in multiindexable; will save a couple computation steps compared to current implementation
        end

        # sets all elements in this view 
        protected def set(src : MultiIndexable(R))
            # TODO: perform relevant size/shape checks and replace src[coord] with src.unsafe_fetch_element(coord)
            ensure_writable
            each_with_coord {|el, coord| @src.unsafe_set_element(@transform.apply(coord), src[coord])} 
        end

        # sets all elements in this view
        protected def set(value : R)
            ensure_writable
            each_with_coord {|el, coord| @src.unsafe_set_element(@transform.apply(coord), value)}
        end

    end
end