require "./view_object"

module Lattice

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