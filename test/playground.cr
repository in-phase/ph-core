require "../src/lattice"
require "complex"

include Lattice


arr = [[1,2,3]]
arr2 = [[4,5,6]]

# narr = NArray.new(arr)
# narr2 = NArray.new(arr2)

# narr << narr2
# puts narr, "\n"
# narr << narr
# puts narr
# puts narr.axis_strides


# puts my1, my2
# my1 << my2



# puts 1..2..3
# puts typeof(1..2..3)

# puts typeof((1..5).step(1))

# def test(range, step)
#     puts (range.end - range.begin) % step
# end

# test(1..6, 3)
# test(6..1, 3)
# test(6..2, -2)
# test(2..6, 2)

# include RegionHelpers

# shape = [5,5,5,5,5,5,5]

# region1 = [1.., ..., ..3, ...5, 3...1, 4.., 1...2]
# region2 = [0..2..4, 1..1..4, 3..-1..2, 1..2..4, ..2.., ..1...5, 1..2..]


# puts canonicalize_region(region1, shape)
# puts canonicalize_region(region2, shape)

# puts NArray.concatenate(my, my0, axis: 0), "\n"
# my0 = my0.reshape([2,3,2])
# puts NArray.concatenate(my, my0, axis: 1), "\n"
# my0 = my0.reshape([2,2,3])
# puts NArray.concatenate(my, my0, axis: 2), "\n"


# large = NArray.build([5,5,10]) {|coord, i| coord}


# pv = ProcessedView.of(large) {|x| x.to_s }
# pvv = pv.process {|x| x + "%"}
# pvvv = pvv.view(1..2, 1..2, 1..2..9)
# puts pvvv, typeof(pvvv), pvvv.region
# v = View.of(large)
# puts v.get(3,4,7)
# puts pvvv.get(0,1,2)
# puts pvvv.transpose
# vv = v.process {|x| x.to_s}


small = NArray.build([2,3,4]) {|coord, i| coord}

view = View.of(small)
view2 = view.view(.., 0..1, 1..3)

puts small
puts view2
puts view2.get(0,1,1), "\n\n"

view2.transpose!

puts view2
puts small

view2[1,1,0] = [123456789]
puts view2, "\n"
puts small, "\n"
view2[2,1] = [567]
puts view2, "\n"
puts small, "\n"

michael = View.of(small)
michael = michael.view(..., ..., 0..2...)
puts michael
puts michael.shape
# michael = michael.view(..., ..., 0..2...) <= this may drop dimension
# michael = michael.view(..., 1..3, ...) <= put this back and deal with it!! has out-of-bounds, but runtime and unclear. Catch sooner
michael = michael.view(..., 1..2, ...)
puts michael
puts michael.shape

puts michael.get(1,1,1) # => [1, 2, 2]]

# sub = NArray.fill([2,2], [10101])
# view2[0] = sub
# puts view2, "\n"
# puts small, "\n"

# puts view2.region, view2.get(0,0,0), view2.get(-1,-1,-1)
# view2.reverse!
# puts view2.region, view2.get(0,0,0), view2.get(-1,-1,-1)


# puts view2
# pv = view2.process {|e| -e[0]}
# puts pv
# puts pv.get(0,1,0)

# # This gives the following error: (trying to call a setter on a ProcessedView)
# # Error: undefined method '[]=' for Lattice::ProcessedView(Array(Int32), Int32)
# # pv[0,0,0] = [5]

# narr = NArray.new([["test", "happy"], ["party", "friend"]])
# # result = NArray.apply(narr, center, 20, '*')

# narr2 = NArray.new([[1, 3], [2, 4]])
# #result2 = NArray.apply(narr, :[], 0, narr2)
# NArray.apply(narr, :[], 0)
# #puts result2


complex_arr = NArray.build([2,2,2]) {|coord, i| i.i}

puts "\n\n", complex_arr

puts 1 + complex_arr

real_arr = NArray.build([2,2,2]) {|coord, i| i}

puts "\n\n", real_arr

real_arr = 1.i + real_arr
puts real_arr.map { |el| el.polar }