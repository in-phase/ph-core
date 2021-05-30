require "./readonly_view"

module Lattice

    class ProcView(S, T, R) < ReadonlyView(S, T, R)
        
        @proc : Proc(T, R)


        # def self.of(src : B, region = nil) : ProcView(S,T,T)  forall T
        #     if src.is_a?(View) 
        #         src.view(region)
        #     else
        #         region = ViewObject.parse_region(region, src, Order.reverse?(order))
        #         ProcessedView(B, T,T).new(src, region, Order.colex?(order), Proc(T,T).new &.itself)
        #     end
        # end

        # # TODO: document
        # def self.of(src : B, region = nil, &block : (T -> R)) : ProcView(S,T,R) forall T,R
        #     if src.is_a?(View)
        #         src.view(region, &block)
        #     else
        #         region = ViewObject.parse_region(region, src, Order.reverse?(order))
        #         ProcessedView(B, T,R).new(src, region, Order.colex?(order), block)
        #     end
        # end

        protected def initialize(@src : S, @shape : Array(Int32), @proc : Proc(T,R), @transform = ComposedTransform.new)
        end    

        def clone : self
            new(@src, @shape.clone, @proc.clone, @transform.clone)
        end

        def unsafe_fetch_element(coord) : R
            @src.unsafe_fetch_element(@transform.apply(coord))
        end

        def unsafe_fetch_region(region) : self
            view(region)
        end

        def process
        end

        def process!(proc)
        end


        def process(&block : (R -> U)) : ProcView(T, U) forall U
            view(@region, &block)
        end

        def process(&block : (R -> U)) : ProcView(S, T, U) forall U
            composition = Proc(T,U).new {|x| block.call(@proc.clone.call(x))}
            ProcView(S ,T, U).new(@src, new_region, @is_colex ^ Order.colex?(order), composition)
        end
    end
end