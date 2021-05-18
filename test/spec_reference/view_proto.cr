require "../../src/lattice"

include Lattice

# narr = NArray.build([4, 4, 4]) { |coord| coord }

# # getting regions

# # Returns a new NArray
# narr[0..2]

# # Returns a view on the same elements
# narr.view(0..2)

# # Does the same thing
# View.of(narr, [0..2])

# # Old method for doing a colex each
# # narr.each(order: Order::COLEX) do ...

# narr.view(order: Order::COLEX) # .each yadda yadda

# # Composing views
# puts narr.view(0..2).view(.., 0..1)
# puts
# puts narr.view(0..2, 0..1)

# Transposition
narr = NArray.build([3, 3]) { |c, i| i }
# puts narr.view(0...2, 0...2)
# puts narr.view(0...2, 0...2).transpose

# Cursed compositions

#.view(2..0, 0..-2) # .transpose.view(.., 0...1).transpose
narr = NArray.build([3, 3]) { |c, i| i }
whoa = View.of(narr) 
whoa[0, 0] = 5

processed = whoa.process do |el|
    el ** 2
end

puts processed, "\n\n"
puts whoa
puts narr