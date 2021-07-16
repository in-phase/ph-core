require "../src/ph-core.cr"

include Phase

puts RegionUtil.translate_shape([1, 2, 3], [1, 2, 3], [10, 10, 10])
