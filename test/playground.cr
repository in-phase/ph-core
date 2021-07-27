require "../src/ph-core"

include Phase 

narr = NArray.build(4, 4, 4) { |c, i| i }
puts narr