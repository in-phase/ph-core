require "../src/ph-core"

include Phase

# narr = NArray.build(4, 4, 4) { |c, i| i }
# puts narr

# 0..2..5

# (0..2)..5

# 0..(2..5)

# rhs = 3..8

# narr[2..rhs]

# Phase::SteppedRange
# sr.first
# sr.step = 5

# Range(Int, Int)
# Range(Range(I,I), I)
# Range(I, Range(I,I))

objs = {0..2..5, (0..2)..5, 0..(1..5), 5.step(to: 3, by: -1, exclusive: true)}
# IndexRegion.new([0..2..5], [10])
objs.each do |obj|
  puts IndexRegion.new([obj], [10])
end

# narr[..., 1.step(to: 10)]
# 1.step(to: 4, by: 0.5) do |i|
#     puts i
# end
