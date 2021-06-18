require "../../src/lattice"

include Lattice

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([5, 5]) { |coord, index| index }

region = [2..1, ..]
canonical = RegionUtil.canonicalize_region(region, [5, 5])
canonical[1] = SteppedRange.new(1..2..4, 5)
puts canonical

puts "The NArray:"
puts small_arr
puts "The region:"
puts small_arr[canonical] # => [[11,13], [6,8]]

# puts "Baseline:"
# small_arr.narray_each_in_canonical_region(canonical) { |elem, idx, idx2| puts elem }

def all_iter_types(class_name, colexiter_class, narr, region)
  puts "\nLexicographic:"
  class_name.new(narr).each { |elem, coord| print elem, " " }
  # sample of what the constructor used to be:
  # NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem }

  puts "\nRev Lex"
  class_name.new(narr, reverse: true).each { |elem, coord| print elem, " " }

  puts "\nColex:"
  class_name.new(narr, iter: colexiter_class).each { |elem, coord| print elem, " " }

  puts "\nRev Colex:"
  class_name.new(narr, reverse: true, iter: colexiter_class).each { |elem, coord| print elem, " " }

  puts "\nLex, region"
  class_name.new(narr, region: region).each { |elem, coord| print elem, " " }
  # Issue here! When I remove the explicit region: tag, it tries to call the protected initializer
  # initialize(@small_arr, @coord_iter)

  puts "\nrev lex region"
  class_name.new(narr, region, true).each { |elem, coord| print elem, " " }

  puts "\ncolex region"
  class_name.new(narr, region, iter: colexiter_class).each { |elem, coord| print elem, " " }

  puts "\nrev colex region"
  class_name.new(narr, region, true, colexiter_class).each { |elem, coord| print elem, " " }

  puts "\n" + "=" * 65 + "\n"
end

puts "BufferedECIterators"

all_iter_types(NArray::BufferedECIterator, NArray::IndexedColexIterator, small_arr, canonical)

puts "RegionIterators"

all_iter_types(MultiIndexable::ElemAndCoordIterator, MultiIndexable::ColexIterator, small_arr, canonical)
