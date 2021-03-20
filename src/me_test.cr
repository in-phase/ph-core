require "./lattice"

include Lattice


arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }

small_arr = NArray.build([3,3]) {|coord, index| index}


pp small_arr.any?

# foo = Foo.new(1)
# puts foo.t
