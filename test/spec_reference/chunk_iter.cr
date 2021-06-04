# cases:
# - evenly tileable, DISCARD/AVAILABLE (should give same result)
# - not evenly tileable, DISCARD/AVAILABLE
# - different stride size, y/n tileable, discard/available

require "../../src/lattice"
require "complex"

include Lattice

alias FringeBehaviour = MultiIndexable::RegionSpecIterator::FringeBehaviour
alias ChunkIterator = MultiIndexable::RegionSpecIterator

def iterate(data, chunk_shape, strides = nil, fb = FringeBehaviour::DISCARD)
  chunks = ChunkIterator.new(data.shape, chunk_shape, strides, fringe_behaviour: fb)
  puts "\n", data
  chunks.each do |idk|
    puts idk
  end
end

tile = NArray.build([4]) { |c, i| i }
nontile = NArray.build([7]) { |c, i| i }

shape = [3]

# iterate(nontile, shape, strides: [1], fb: FringeBehaviour::COVER)
# iterate(nontile, shape, strides: [2], fb: FringeBehaviour::COVER)
# iterate(nontile, shape, strides: [3], fb: FringeBehaviour::COVER)
iterate(nontile, shape, strides: [4], fb: FringeBehaviour::COVER)

# iterate(nontile, shape, strides: [1], fb: FringeBehaviour::ALL_START_POINTS)
# iterate(nontile, shape, strides: [2], fb: FringeBehaviour::ALL_START_POINTS)
# iterate(nontile, shape, strides: [3], fb: FringeBehaviour::ALL_START_POINTS)
# iterate(nontile, shape, strides: [4], fb: FringeBehaviour::ALL_START_POINTS)

# iterate(nontile, shape, strides: [1])
# iterate(nontile, shape, strides: [2])
# iterate(nontile, shape, strides: [3])
# iterate(nontile, shape, strides: [4])

# Documentation notes:
# DISCARD:
# - returns ONLY arrays of shape chunk_shape. If the stride and chunk shape do not perfectly tile the NArray, leftovers at the end are discarded.
# - EX1: for [0,1,2,3] with chunk 2, stride 2, returns: [0,1], [2,3] (tiles)
# - Ex2: for [0,1,2,3] with chunk 3, stride 3, returns: [0,1,2] (does not tile; [3] is discarded)

# COVER:
# - behaves like DISCARD for stride < chunk_shape, and like ALL_START_POINTS otherwise
# - returns truncated arrays at fringes if the stride and chunk shape do not perfectly tile the NArray and the fringe contains elements that have not been encountered before.
# - differs in behaviour from ALL_START_POINTS only when stride < chunk; discards any truncated regions that include already-seen data.
# - Ex1: for [0,1,2,3,4] with chunk 3 and stride 2, will give the following chunks: [0,1,2], [2,3,4]
#    Counting by a stride of 2, possible edge coordinates are 0,2,4.
#    However, the chunk starting with coordinate 4 contains only the element [4], which has already been seen in the chunk starting with 2; so it is discarded.
# - Ex2: for [0,1,2,3,4] with chunk 4 and stride 2, gives: [0,1,2,3], [2,3,4]
#    [2,3,4] does not have full shape ([4]); however, the element [4] has not been seen yet, so the partial chunk must be included.

# ALL_START_POINTS
# - returns truncated arrays at fringes if the stride and chunk shape do not perfectly tile the NArray.
# - selects chunks based on the criteria of its starting coordinate being valid for the narray.
# - differs in behaviour from COVER where stride < chunk: it will
# - Ex1: for [0,1,2,3,4] with chunk 3 and stride 2, will give the following chunks: [0,1,2], [2,3,4], [4]
#   since counting by a stride of 2, possible edge coordinates are 0,2,4
