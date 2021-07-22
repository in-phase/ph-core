require "../src/ph-core"

include Phase 

image = NArray.build(3, 3) { |c| c.sum }
puts image

image[1.., ..1] *= 10
puts image

# puts image[1.., ..1]