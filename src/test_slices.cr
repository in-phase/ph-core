require "./lattice"


arr = Lattice::NArray.build([2,3,2,3]) {|coord,index| index}
coord_arr = Lattice::NArray.build([2,3,2,3]) {|coord,index| coord}


puts arr.slices(0)
puts arr.slices(1)