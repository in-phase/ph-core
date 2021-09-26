require "../src/iterators/stride_iterator.cr"
require "../src/iterators/lex_iterator.cr"

first = [2, 1, 3]
step = [2, 1, 1]
last = [5, 2, 4]

iter = Phase::LexIterator.new(first, step, last)
iter.each do |coord|
    puts coord
end