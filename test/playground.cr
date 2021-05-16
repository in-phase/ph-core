require "../src/lattice"
require "complex"

include Lattice

data = NArray.build([5, 5]) { |c, i| i }
puts data

chunks = MultiIndexable::ChunkIterator(NArray(Int32), Int32).new(data, [2, 2], fringe_behaviour: MultiIndexable::ChunkIterator::FringeBehaviour::AVAILABLE)
chunks.each do |idk|
    puts idk[0]
end