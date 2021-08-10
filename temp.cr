require "./src/ph-core"
require "benchmark"
require "./spec/test_narray"

include Phase

# You can construct n-dimensional arrays from literals:
narr1 = NArray[[6, 3, 7], [1, 5, 4]]
narr_big = NArray[[6, 3, 7], [1, 5, 4], [1, 2, 3]]

# Or programatically using the coordinates:
narr2 = NArray.build(2,3) do |coord| 
    10 * coord[0] + coord[1]
end

# str_narr = NArray.build(3,3) {|_, i| "hello world"[i] }
# puts str_narr.apply.upcase


# def multi(&block)
#     yield(1,2,3)
# end

# multi {|*x| puts x}

def each_with2(*args : *U, &block) forall U
    {% begin %}
        {% found_first = false %}
        {% for i in 0...(U.size) %}
            {% if U[i] < NArray %}
                {% if found_first == false %}
                    {% found_first = true %}
                    first = args[{{i}}]
                {% else %}
                    raise ShapeError.new("Could not simultaneously map NArrays with shapes #{args[{{i}}].shape} and #{first.shape}.") unless args[{{i}}].shape == first.shape
                {% end %}
            {% elsif U[i] < MultiIndexable %}
                map_multiple(*args) do |*elems|
                    yield *elems
                end

                return
            {% end %}
        {% end %}

        first.size.times do |buf_idx|
            yield(
                {% for i in 0...(U.size) %}
                    {% if U[i] < NArray %} args[{{i}}].@buffer.unsafe_fetch(buf_idx) {% else %} args[{{i}}]{% end %},
                {% end %}
            )
        end
    {% end %}
end

each_with2(narr1, narr2) do |a,b|
    puts ({a,b})
end

puts narr1.apply.* 5
# puts narr1.apply.fake

# Benchmark.ips do |x|

#     x.report("map_multiple_narrs") do
#         map_multiple_narrs(narr1.unsafe_as(MultiIndexable(Int32)), narr2, narr1, narr1, 5) do |*elems|
#             elems
#         end
#     end

#     x.report("map_multiple") do
#         map_multiple(narr1, narr2, narr1, narr1, 5) do |*elems|
#             elems
#         end
#     end

#     x.report("map with coord") do 
#         narr1.each_with_coord do |el, coord|
#             {el, narr2.get(coord), narr1.get(coord), narr1.get(coord), 5}
#         end
#     end

# end