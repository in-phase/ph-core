require "../lattice"

module Lattice

    class View(T, R)
        include MultiIndexable(R)
        include RegionHelpers

        getter src : MultiIndexable(T)
        getter region : Array(SteppedRange)
        @proc : Proc(T,R)
        @is_colex : Bool

        # Cached data
        @shape : Array(Int32)
        getter size : Int32

        def self.of(src : MultiIndexable(T), region = nil, order = Order::LEX, proc : Proc(T,R) = Proc(T,T).new {|x| x} )
            region = region ? canonicalize_region(region) : RegionHelpers.full_region(src.shape)
            region = region.map &.reverse if Order.reverse?(order) 
            View(T,R).new(src, region, Order.colex?(order), proc)
        end

        # def self.of(src : MultiIndexable(T), region = nil) : View(T,T)
        #     order=  Order::LEX
        #     proc = Proc(T,T).new {|x| x}

        #     region = region ? canonicalize_region(region) : RegionHelpers.full_region(src.shape)
        #     region = region.map &.reverse if Order.reverse?(order) 
        #     self.new(src, region, Order.colex?(order), proc)
        # end

        protected def initialize(@src : MultiIndexable(T), @region, @is_colex : Bool, @proc : Proc(T,R))
            @shape = measure_canonical_region(@region)
            @size = @shape.product
        end

        def shape : Array(Int32)
            @shape.dup
        end

        def unsafe_fetch_element(coord) : R
            @proc.call(@src.unsafe_fetch_element(local_coord_to_srcframe(coord)))
        end

        def unsafe_fetch_region(region) : View(T,R)
            view(region)
        end

        protected def local_coord_to_srcframe(coord) : Array(Int32)
            @region.map_with_index { |range, dim| range.local_to_absolute(coord[dim]) }
        end

        protected def local_region_to_srcframe(region, reverse) : Array(SteppedRange)
            if reverse
                new_region = region.map_with_index do |range, dim|
                    range.compose(region[dim]).reverse
                end
            else
                new_region = region.map_with_index { |range, dim| range.compose(region[dim])}
            end
            new_region
        end

        def view(*region)
            view(region)
        end

        def view(region, order = Order::LEX, proc : Proc(R,U) = Proc(R,R).new {|x| x} ) forall U
            new_region = local_region_to_srcframe(canonicalize_region(region, @shape), Order.reverse?(order))

            inner = @proc.clone
            composition = Proc(T,U).new {|x| proc.call(inner.call(x))}

            View(T,U).new(@src, new_region, @is_colex ^ Order.colex?(order), composition)
        end

        def to_narr
        end
    end
end