require "../src/lattice"
require "benchmark"
include Lattice
include MultiIndexable(Int32)

# # Make a ElemAndCoordIterator by getting coord and composing with ElemIterator
# class Wrap(T)
#     include Iterator(Tuple(T, Array(Int32)))
    
#     @elem_iter : ElemIterator(T)

#     def initialize(@elem_iter : ElemIterator(T))
#     end

#     def next
#         case item =  @elem_iter.next
#         when Stop
#             return item
#         else
#             return {item, @elem_iter.coord_iter.coord}
#         end
#     end
    
#     def unsafe_next
#         {@elem_iter.unsafe_next, @elem_iter.coord_iter.coord}
#     end
# end

# This is an analogy for how we could make an ElemIterator by dropping coord from ElemAndCoordIterator
class Discard(T)
    include Iterator(T)

    @iter : ElemAndCoordIterator(T)
    
    def initialize(@iter : ElemAndCoordIterator(T))
    end

    def next
        @iter.next_value
    end

    def unsafe_next
        @iter.unsafe_next_value
    end
end

alias Wrap = ElemIterator

shape = [50, 50, 50]
narr = NArray.build(shape) { |c, i| i }
region = RegionUtil.canonicalize_region([..], shape)

size = shape.product

Benchmark.bm do |x|
    e_iter = ElemIterator.of(narr, region)
    w_iter = Wrap.new(e_iter)

    x.report("wrap") do
        w_iter.each do end
    end

    r_iter = ElemAndCoordIterator.of(narr, region)

    r_iter.reset

    x.report("base") do
        r_iter.each do end
    end

    e_iter.reset 
    r_iter.reset
    
    d_iter = Discard.new(r_iter)
    # x.report("discard unsafe") do 
    #     (size - 1).times do
    #         d_iter.unsafe_next
    #     end
    # end

    x.report("wrap unsafe") do 
        (size - 1).times do 
            w_iter.unsafe_next
        end
    end

    # r_iter.reset
    x.report("discard") do
        d_iter.each do end
    end
end