require "./src/ph-core"
require "./spec/test_narray"

include Phase

class Ham(S, R) < ReadonlyView(S, R)
end  

test_shape = [3, 4]

# narr = uninitialized NArray(Int32) # NArray.build(test_shape) {|c,i| i}
test_buffer = Slice[1,2,3,4,5,6,7,8,9,10,11,12]

ronarr = RONArray.new(test_shape, test_buffer)
data = ReadonlyView.of(ronarr).to_narr

puts "after making"
puts data