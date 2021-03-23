require "../src/lattice"

include Lattice


arr = [[1,2,3]]

arr2 = [[4,5,6]]

narr = NArray.new(arr)
narr2 = NArray.new(arr2)

narr << narr2

puts narr, "\n"


narr << narr

puts narr

puts narr.buffer_step_sizes


my1 = NArray.build([3,3]) {|coord, i| i}
my2 = NArray.build([3,3]) {|coord, i| i + 8}

puts my1, my2

my1 << my2



puts 1..2..3
puts typeof(1..2..3)

puts typeof((1..5).step(1))