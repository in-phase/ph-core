require "../lattice"

module Lattice


    module ViewObject(T,R)
        include MultiIndexable(R)

        getter src : MultiIndexable(T)
        getter region : Array(RegionHelpers::SteppedRange)
        @is_colex : Bool

        @shape : Array(Int32)
        getter size : Int32
        
        abstract def view(region, order : Order)
        abstract def process(&block : R -> U) forall U

        def shape : Array(Int32)
            @shape.dup
        end

        def view(*region)
            view(region, order: Order::LEX)
        end

        def to_narr(type : MultiIndexable.class = NArray)
            begin
            rescue exception
                raise NotImplementedError.new()
            end
        end

        protected def self.parse_region(region, src, reverse : Bool) : Array(RegionHelpers::SteppedRange)
            new_region = region ? RegionHelpers.canonicalize_region(region, src.shape) : RegionHelpers.full_region(src.shape)
            new_region.map! &.reverse if reverse
            new_region
        end

        protected def parse_region(region, reverse : Bool) : Array(RegionHelpers::SteppedRange)
            new_region = local_region_to_srcframe(RegionHelpers.canonicalize_region(region, @shape))
            new_region.map! &.reverse if reverse
            new_region
        end

        protected def local_coord_to_srcframe(coord) : Array(Int32)
            @region.map_with_index { |range, dim| range.local_to_absolute(coord[dim]) }
        end

        protected def local_region_to_srcframe(region) : Array(RegionHelpers::SteppedRange)
            @region.map_with_index { |range, dim| range.compose(region[dim])}
        end

    end

    class View(T)
        include MultiIndexable(T)
        include MultiWritable(T)
        include ViewObject(T,T)


        def self.of(src : MultiIndexable(T), region = nil, order : Order = Order::LEX) : View(T) forall T
            if src.is_a?(View) 
                src.view(region, order)
            else
                new_region = ViewObject.parse_region(region, src, Order.reverse?(order))
                View(T).new(src, new_region, Order.colex?(order))
            end
        end

        protected def initialize(@src : MultiIndexable(T), @region, @is_colex : Bool)
            @shape = RegionHelpers.measure_canonical_region(@region)
            @size = @shape.product
        end

        def process(&block : T -> R) : ProcessedView(T,R) forall R
            ProcessedView.new(@src, @region, @is_colex, block)
        end

        def unsafe_fetch_element(coord) : T
            @src.unsafe_fetch_element(local_coord_to_srcframe(coord))
        end

        def unsafe_set_element(coord)
            @src.unsafe_set_element(local_coord_to_srcframe(coord))
        end

        def unsafe_fetch_region(region) : View(T)
            view(region)
        end

        def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))
            # TODO: implement
            raise NotImplementedError.new()
        end

        def unsafe_set_region(region : Enumerable, value : T)
            # TODO: implement
            raise NotImplementedError.new()
        end

        def view(region, order : Order = Order::LEX) : View(T)
            new_region = parse_region(region, Order.reverse?(order))
            View(T).new(@src, new_region, @is_colex ^ Order.colex?(order), @proc)
        end
    end

    class ProcessedView(T, R)
        include MultiIndexable(R)
        include ViewObject(T,R)

        getter proc : Proc(T,R)

        # TODO: document
        def self.of(src : MultiIndexable(T), region = nil, order : Order = Order::LEX) : ProcessedView(T,T)  forall T
            if src.is_a?(View) 
                src.view(region, order)
            else
                region = ViewObject.parse_region(region, src, Order.reverse?(order))
                ProcessedView(T,T).new(src, region, Order.colex?(order), Proc(T,T).new &.itself)
            end
        end

        # TODO: document
        def self.of(src : MultiIndexable(T), region = nil, order : Order = Order::LEX, &block : (T -> R)) : ProcessedView(T,R) forall T,R
            if src.is_a?(View)
                src.view(region, order, &block)
            else
                region = ViewObject.parse_region(region, src, Order.reverse?(order))
                ProcessedView(T,R).new(src, region, Order.colex?(order), block)
            end
        end

        protected def initialize(@src : MultiIndexable(T), @region, @is_colex, @proc : Proc(T,R))
            @shape = RegionHelpers.measure_canonical_region(@region)
            @size = @shape.product
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

        def view(region, order : Order = Order::LEX) : ProcessedView(T,R)
            new_region = parse_region(region, Order.reverse?(order))
            ProcessedView(T,R).new(@src, new_region, @is_colex ^ Order.colex?(order), @proc)
        end

        def view(region, order : Order = Order::LEX , &block : (R -> U)) : ProcessedView(T, U) forall U
            new_region = parse_region(region, Order.reverse?(order))
            composition = Proc(T,U).new {|x| block.call(@proc.clone.call(x))}
            ProcessedView(T, U).new(@src, new_region, @is_colex ^ Order.colex?(order), composition)
        end
    end
end