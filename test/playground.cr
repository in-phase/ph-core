require "../src/lattice"

include Lattice

narr = NArray.build([3,2,4]) {|c,i| i}

narr2 = NArray.build([3,2,4]) {|c,i| 300 + i}

big = NArray.build([10,10,10,10]) {|c,i| i}
# puts narr

# big.concatenate!(narr2, axis: 0)
puts big[..2.., -1..0, 3, ..]

# LexIterator.cover(narr.shape).each do |coord|
#   puts({coord, narr.get(coord)})
# end

# puts narr.@buffer