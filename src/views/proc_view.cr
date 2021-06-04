require "./readonly_view"

module Lattice

    class ProcView(S, T, R) < ReadonlyView(S, R)
        @proc : Proc(T, R)

        # # TODO: document
        def self.of(src : S, proc : (T -> R)) : ProcView(S,T,R) forall T,R
            {% begin %}
                {% unless S < MultiIndexable(T) %}
                    {% raise "Error creating ProcView: proc input type does not match source element type." %}
                {% end %}
            {% end %}

            case src
            when ReadonlyView
                return src.process(proc)
            else
                return ProcView(S, T, R).new(src, src.shape, proc)
            end 
        end

        def self.of(src : B, &block : (T -> R)) : ProcView(S,T,R) forall T,R
            self.of(src, block)
        end

        protected def initialize(@src : S, @shape : Array(Int32), @proc : Proc(T,R), @transform = ComposedTransform.new)
        end

        def clone : self
            new(@src, @shape.clone, @proc.clone, @transform.clone)
        end

        def unsafe_fetch_element(coord) : R
            @proc.call(@src.unsafe_fetch_element(@transform.apply(coord)))
        end

        def process(new_proc : (R -> U)) : ProcView(S, T, U) forall U
            composition = Proc(T,U).new {|x| new_proc.call(@proc.clone.call(x))}
            ProcView(S ,T, U).new(@src, @shape.clone, composition, @transform.clone)
        end
         
    end
end