require "./lattice"


arr = Lattice::NArray.build([2,3,2,3]) {|coord,index| index}
coord_arr = Lattice::NArray.build([2,3,2,3]) {|coord,index| coord}


puts "Axis 1 slices:"

(0...2).each do  |i|
    puts "Slice #{i}"
    puts arr[i]
    puts coord_arr[i]
end

puts "Axis 2 slices:"

(0...3).each do |i|
    puts "Slice #{i}"
    puts arr[.., i]
    puts coord_arr[.., i]
end


puts coord_arr[.., 2]