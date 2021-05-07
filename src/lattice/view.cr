require "../lattice"

module Lattice

    # Views, like any MultiIndexable, may be iterated over in an arbitrarily defined order; however, 
    # they can only be stored internally as one of the 4 primary orders (Lex, Colex, RevLex, RevColex)
    # as (barring contrived edge cases) these seem to be the only orderings that make sense for 
    # a MultiIndexable structure.

    module ViewObject(B,T,R)
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

    class ProcessedView(B, T, R)
        include MultiIndexable(R)
        include ViewObject(B,T,R)

        getter proc : Proc(T,R)

        # TODO: document
        def self.of(src : B, region = nil, order : Order = Order::LEX) : ProcessedView(B, T,T)  forall T
            if src.is_a?(View) 
                src.view(region, order)
            else
                region = ViewObject.parse_region(region, src, Order.reverse?(order))
                ProcessedView(B, T,T).new(src, region, Order.colex?(order), Proc(T,T).new &.itself)
            end
        end

        # TODO: document
        def self.of(src : B, region = nil, order : Order = Order::LEX, &block : (T -> R)) : ProcessedView(B, T,R) forall T,R
            if src.is_a?(View)
                src.view(region, order, &block)
            else
                region = ViewObject.parse_region(region, src, Order.reverse?(order))
                ProcessedView(B, T,R).new(src, region, Order.colex?(order), block)
            end
        end

        protected def initialize(@src : B, @region, @is_colex, @proc : Proc(T,R))
            @shape = RegionHelpers.measure_canonical_region(@region)
            @shape = @shape.reverse if @is_colex
            @size = @shape.product
        end

        # Calls `each_in_region` on `@src` is not an option here, since then the conversions do not happen;
        # we can, however, override the block-accepting version to be faster.
        def each(&block)
            order = @is_colex ? Order::COLEX : Order::LEX
            @src.each_in_canonical_region(@region, order: order) do |elem, coord|
                yield @proc.call(elem)
            end
        end

        def clone
            ProcessedView(B,T,R).new(@src, @region.dup, @is_colex, @proc.dup)
        end

        # TODO: document
        def unsafe_fetch_element(coord) : R
            @proc.call(@src.unsafe_fetch_element(local_coord_to_srcframe(coord)))
        end

        # TODO: document
        def unsafe_fetch_region(region) : ProcessedView(T,R)
            view(region)
        end

        # TODO: document
        def process(&block : (R -> U)) : ProcessedView(T, U) forall U
            view(@region, &block)
        end

        def view(region, order : Order = Order::LEX) : ProcessedView(B, T,R)
            new_region = parse_and_convert_region(region, Order.reverse?(order))
            ProcessedView(B,T,R).new(@src, new_region, @is_colex ^ Order.colex?(order), @proc)
        end

        def view(region, order : Order = Order::LEX , &block : (R -> U)) : ProcessedView(B,T, U) forall U
            new_region = parse_and_convert_region(region, Order.reverse?(order))
            composition = Proc(T,U).new {|x| block.call(@proc.clone.call(x))}
            ProcessedView(B,T, U).new(@src, new_region, @is_colex ^ Order.colex?(order), composition)
        end
    end
end