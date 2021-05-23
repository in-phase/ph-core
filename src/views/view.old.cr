require "./view_object"

module Lattice

    class View(B,T)
        include ViewObject(B,T,T)
        include MultiWritable(T)

        macro ensure_writable
            {% unless B < MultiWritable %}
                {% raise "Could not write to #{@type}: #{B} is not a MultiWritable." %}
            {% end %}
        end

        def self.of(src : B, region = nil, order : Order = Order::LEX)
            if src.is_a?(View) 
                src.view(region, order)
            else
                new_region = ViewObject.parse_region(region, src, Order.reverse?(order))
                View(B, typeof(src.sample)).new(src, new_region, Order.colex?(order))
            end
        end

        # TODO: Should be protected 
        protected def initialize(@src : MultiIndexable(T), @region, @is_colex : Bool)
            @shape = RegionHelpers.measure_canonical_region(@region)
            @shape = @shape.reverse if @is_colex
            @size = @shape.product
        end

        def clone
            View(B, T).new(@src, @region.dup, @is_colex)
        end

        def process(&block : T -> R) forall R
            ProcessedView(B, T, R).new(@src, @region, @is_colex, block)
        end

        # Calls `each_in_region` on `@src`, as a faster alternative to the default of
        # calling `each` on `self` which must convert every index
        def each
            order = @is_colex ? Order::COLEX : Order::LEX
            @src.each_in_canonical_region(@region, order: order)
        end

        def unsafe_fetch_element(coord) : T
            @src.unsafe_fetch_element(local_coord_to_srcframe(coord))
        end

        def unsafe_fetch_region(region) : View(T)
            view(region)
        end

        def unsafe_set_element(coord)
            ensure_writable
            @src.unsafe_set_element(local_coord_to_srcframe(coord))
        end

        def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))
            ensure_writable
            @src.unsafe_set_region(local_region_to_srcframe(region), src)
        end

        def unsafe_set_region(region : Enumerable, value : T)
            ensure_writable
            @src.unsafe_set_region(local_region_to_srcframe(region), value)
        end

        def view(region, order : Order = Order::LEX) : View(B, T)
            new_region = parse_and_convert_region(region, Order.reverse?(order))
            View(B, T).new(@src, new_region, @is_colex ^ Order.colex?(order))
        end
    end
end