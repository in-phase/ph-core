require "../../src/lattice"

include Lattice

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([5, 5]) { |coord, index| index }
huge_arr = NArray.build([100, 100]) { |_, index| index }

region_literal = [2..1, 1..2..4]
region = IndexRegion.new(region_literal, [5,5])


# puts LexIterator(Int32).new([4,5])

puts "The NArray:"
puts small_arr
# puts "The region:"
# puts small_arr[canonical] # => [[11,13], [6,8]]

# puts "Baseline:"
# small_arr.narray_each_in_canonical_region(canonical) { |elem, idx, idx2| puts elem }

def all_iter_types(class_name, colexiter_class, co_reg_iter, narr, region)
  puts "\nLexicographic:"
  class_name.of(narr).each { |elem, coord| print elem, " " }
  # sample of what the constructor used to be:
  # NArray::BufferedLexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem }

  puts "\nRev Lex"
  class_name.of(narr).reverse.each { |elem, coord| print elem, " " }

  puts "\nColex:"
  class_name.of(narr, colexiter_class.cover(narr.shape)).each { |elem, coord| print elem, " " }

  puts "\nRev Colex:"
  class_name.of(narr, colexiter_class.cover(narr.shape)).reverse.each { |elem, coord| print elem, " " }

  puts "\nLex, region"
  class_name.of(narr, region).each { |elem, coord| print elem, " " }
  # Issue here! When I remove the explicit region: tag, it tries to call the protected initializer
  # initialize(@small_arr, @coord_iter)

  puts "\nrev lex region"
  class_name.of(narr, region).reverse.each { |elem, coord| print elem, " " }

  puts "\ncolex region"
  class_name.of(narr, co_reg_iter).each { |elem, coord| print elem, " " }

  puts "\nrev colex region"
  class_name.of(narr, co_reg_iter).reverse.each { |elem, coord| print elem, " " }

  puts "\n" + "=" * 65 + "\n"
end

puts "BufferedECIterators"
co_reg_iter = NArray::IndexedColexIterator.new(region, small_arr.shape)
all_iter_types(NArray::BufferedECIterator, NArray::IndexedColexIterator, co_reg_iter, small_arr, region)

# puts "RegionIterators"
co_reg_iter = ColexIterator.new(region)
all_iter_types(ElemAndCoordIterator, ColexIterator,co_reg_iter, small_arr, region)
