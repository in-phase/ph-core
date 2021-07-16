require "../src/lattice.cr"

include Lattice

puts RegionUtil.translate_shape([1, 2, 3], [1, 2, 3], [10, 10, 10])
