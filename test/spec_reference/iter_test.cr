require "../../src/lattice"

include Lattice

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([5, 5]) { |coord, index| index }


region = [2..1, ..]
canonical = RegionHelpers.canonicalize_region(region, [5,5])
canonical[1] = RegionHelpers::SteppedRange.new(1..2..4, 5)
puts canonical

puts small_arr[canonical] # => [[2,1], [5,4]]

puts "Lexicographic:"
NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem }

puts "Colexicographic:"
NArray::BufferedColexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem }

puts "Lexicographic, region"
NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr, canonical).each { |elem, coord| puts elem , coord}

puts "Baseline:"
small_arr.narray_each_in_canonical_region(canonical) {|elem, idx, idx2| puts elem}

# puts "Colex, region"
# NArray::BufferedColexRegionIterator(typeof(small_arr), Int32).new(small_arr, canonical).each { |elem, coord| puts elem }

# puts "rev lex"
# NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem }


# puts "rev colex"
# NArray::BufferedColexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem }

# puts "rev lex region"
# NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr, canonical, reverse: true).each { |elem, coord| puts elem }


# puts "rev colex region"
# NArray::BufferedColexRegionIterator(typeof(small_arr), Int32).new(small_arr, canonical, reverse: true).each { |elem, coord| puts elem }


MultiIndexable::LexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem, coord }
MultiIndexable::ColexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem, coord }

# puts "Reverse Lexicographic:"
# MultiIndexable::LexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem, coord }

# puts "Reverse Colexicographic:"
# MultiIndexable::ColexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem, coord }

# puts "Reversed Lexicographic:"
# MultiIndexable::ColexRegionIterator(typeof(small_arr), Int32).new(small_arr).reverse.each { |elem, coord| puts elem, coord }

# puts "Slices, axis 0:"
# SliceIterator.new(small_arr).each {|elem| puts elem}

# puts "Slices, axis 1:"
# SliceIterator.new(small_arr, axis=1).each {|elem| puts elem}

# iter.each {|elem| puts elem}

# item_iter = ItemIterator(NArray(Int32), Int32).new(arr)
# item_iter.each {|elem| puts elem}
