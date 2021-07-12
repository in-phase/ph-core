require "../src/lattice"

include Lattice 





narr = NArray.build(10, 2) {|c,i| i}

# puts narr[.., 0,2]

narr.slices(2).each do |slice|
    x, y = slice
    puts Math.sqrt(x**2 +  y**2)
end

sqrt(x^2+(x+1)^2) == sqrt(2x^2+2x+1)