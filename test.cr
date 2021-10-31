require "./src/ph-core.cr"

include Phase

# r = IndexRegion.new([2..4, 3..5], [10, 10])
# NArray::BufferUtil::IndexedLexIterator.new(r)
narr = NArray[[1, 2, 3], [4, 5, 6]]
narr.each.reverse_each do |el| #.with_coord.reverse_each do |el|
    puts el
end