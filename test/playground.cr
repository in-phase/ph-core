require "../src/lattice"

include Lattice

shape = [5, 3, 4]#, 3, 20, 20, 20, 20]
# region = [.., .., .., .., .., 5..15]
# canon = RegionHelpers.canonicalize_region(region, shape)

# narr = NArray.build(shape) {|c,i| 1}
puts (Time.measure do 
    narr = NArray.build(shape) {|c,i| i}
    puts narr.size
    puts narr
end)

puts (Time.measure do 
    narr = NArray.fill(shape, 5)
    
end)

puts (Time.measure do
    i = -1
    narr = NArray(Int32).new(shape) {i += 1}
    puts narr
end)
 

# current implementation: 17 s


# puts (Time.measure do
#     sum = 0
#     iter = MultiIndexable::LexRegionIterator(typeof(narr), Int32).new(narr, canon)
#     iter.each do |el, _|
#         sum += el
#     end
#     puts sum
# end)


# puts (Time.measure do 
#     sum = 0
#     view = View.of(narr).view(region).permute!.view([..]).permute!
#     view.each do |el|
#         sum += el
#     end
#     puts sum
# end)


# class Foo 
# end

# class Bar < Foo 
# end

# puts Bar.new.is_a?(Foo)


# narr = NArray.build([2,4,3]) {|c,i| i}
# puts narr
# view = View.of(narr, [..., 1..2])
# puts view
# view = view.view([0,.., ..2..])
# puts view.reshape!([4])
# puts view.permute! # NOTE: should "permute" work for 1D?

# view2 = View.of(narr, [.., 1..2])
# puts view2
# puts view2.permute!
# puts view2.reshape!([4,3])


# view2[1..2..,1..] = -3 #NArray.new([[-1,-2],[-3,-4]])
# puts view2

# puts narr
# puts view2
# narr[0, ..1] = -5
# narr.unsafe_set_element([1,1,0], 100)
# # view2 = 
# puts view2

# puts narr


