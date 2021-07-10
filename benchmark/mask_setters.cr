require "../src/lattice"
require "benchmark"
include Lattice

narr = NArray.build(3,3,3) {|c,_| c.sum }
puts narr

narr[(narr % 2).eq 1] *= 20
# narr[narr < 6] = 20 + narr
# puts narr > 2
# puts narr < 6
# puts (narr > 2) & (narr < 6)
# puts narr > 2 & narr < 6

# Benchmark.ips do |x|

#     x.report("square bracket method") do
#         narr[(narr % 2).eq 1] = 1 + narr
#     end
 
#     x.report("factored method") do
#         narr.set_mask(((narr % 2).eq 1), 1 + narr)
#     end

# end
