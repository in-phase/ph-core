require "./src/ph-core.cr"

include Phase

r = IndexRegion.new([2..4, 3..5], [10, 10])
NArray::BufferUtil::IndexedLexIterator.new(r)