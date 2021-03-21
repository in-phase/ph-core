require "../lattice"

include Lattice

arr = Lattice::NArray.build([2, 3, 2, 3]) { |coord, index| index }
coord_arr = Lattice::NArray.build([2, 3, 2, 3]) { |coord, index| coord }

# puts arr
# puts arr.slices
# puts arr.slices(1)
# puts arr.slices(2)
# puts arr.slices(3)

# my_shape = arr.shape

# my_shape[2] = 7

# pp arr
