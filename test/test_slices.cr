require "../src/lattice"

include Lattice

arr = Lattice::NArray.build([2, 3, 2, 3]) { |coord, index| index }
coord_arr = Lattice::NArray.build([2, 3, 2, 3]) { |coord, index| coord }

puts arr

fill = NArray.fill([2,2,2], -5)

small_arr = NArray.build([2,2]) { |c, i| i}
small_fill = NArray.fill([2], 100)

puts small_arr.shape, small_fill.shape
puts small_arr
small_arr[..,0] = small_fill
puts small_arr

# puts arr.shape, fill.shape
# puts arr[.., 1..2, .., 0].shape
# arr[.., 1..2, .., 0] = fill
# puts arr

# puts arr
# puts arr.slices
# puts arr.slices(1)
# puts arr.slices(2)
# puts arr.slices(3)

# my_shape = arr.shape

# my_shape[2] = 7

# pp arr
