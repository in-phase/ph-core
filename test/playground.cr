require "../src/ph-core"

include Phase 

foo = [1, 2]
bar = [1, 2]
baz = [1, 2]
too_small = [1]

def returns_tuple
    {3, 4, 5, 6}
end

2.times do |i|
    foo[i], bar[i], baz[i], too_small[i] = returns_tuple
end