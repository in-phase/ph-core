require "../src/iterators/stride_iterator.cr"
require "../src/iterators/lex_iterator.cr"
require "../src/iterators/colex_iterator.cr"
require "../src/range_syntax"

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

# puts Phase::RangeSyntax.canonicalize_range(2..2..5, 6) #=> {first: 2, step: 2, last: 4, size: 2}