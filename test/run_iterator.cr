require "../src/iterators/stride_iterator.cr"
require "../src/iterators/lex_iterator.cr"
require "../src/iterators/colex_iterator.cr"
require "../src/multi_indexable/tiling_lex_iterator.cr"
require "../src/range_syntax"

require "../src/multi_indexable"
require "../src/multi_writable"
require "../src/n_array/buffer_util"
require "../src/n_array"
require "../src/index_region"
require "../src/type_aliases"
require "../src/exceptions/*"

first = [2, 1, 3]
step = [2, 1, 1]
last = [4, 2, 4]

iter = Phase::LexIterator.new(first, step, last)
iter.each do |coord|
    puts coord
end

co = Phase::ColexIterator.new(first, step, last)
co.each do |coord|
    puts coord
end

Phase::NArray[1, 2, 3].each { |x| puts x }

module Phase
    module MultiIndexable(T)
        iter = TilingLexIterator.new([0..4, 0..4], [2, 2])
        iter.each do |coord|
            puts({coord, iter.smaller_coord})
        end
    end
end
# puts Phase::RangeSyntax.canonicalize_range(2..2..5, 6) #=> {first: 2, step: 2, last: 4, size: 2}

puts(Phase::LexIterator(Int32).is_a? Iterator(Indexable(Int32)))