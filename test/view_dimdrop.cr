require "../src/ph-core"

include Phase

narr = NArray.build(4, 4, 4) { |_, i| i }

puts narr

puts narr[2]

view = narr.view(2)
puts view
view[.., ..] = 5
puts view
puts narr